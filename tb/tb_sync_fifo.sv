`timescale 1ns/1ps

module tb_sync_fifo;
    // Parameters
    localparam int WIDTH          = 64;
    localparam int DEPTH          = 16;
    localparam int CNT_W          = $clog2(DEPTH) + 1;
    localparam int CLK_PERIOD     = 10;
    localparam int TIMEOUT_CYCLES = 100_000;

    // Signals
    logic             clk = 1'b0;
    logic             rst;
    logic             s_valid;
    logic [WIDTH-1:0] s_data;
    logic             s_ready;
    logic             m_valid;
    logic [WIDTH-1:0] m_data;
    logic             m_ready;
    logic [CNT_W-1:0] count;

    int errors = 0;

    // Reference model: what the FIFO should hold, oldest at index 0
    logic [WIDTH-1:0] model_q [$];

    // How many cycles the FIFO spent full / empty, to confirm the
    // tests actually reached the edge cases
    int full_cycles  = 0;
    int empty_cycles = 0;

    // Clock and DUT
    always #(CLK_PERIOD/2) clk = ~clk;

    sync_fifo #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .s_valid (s_valid),
        .s_data  (s_data),
        .s_ready (s_ready),
        .m_valid (m_valid),
        .m_data  (m_data),
        .m_ready (m_ready),
        .count   (count)
    );

    // ------------------------------------------------------------------
    // Scoreboard: runs at every posedge and sees the values from just
    // BEFORE the edge, i.e. the values the DUT is acting on
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            model_q.delete();
        end else begin
            // Flags and count must agree with the model's occupancy
            if (count !== model_q.size()) begin
                $error("count = %0d, model holds %0d", count, model_q.size());
                errors++;
            end
            if (s_ready !== (model_q.size() != DEPTH)) begin
                $error("s_ready = %b with %0d entries", s_ready, model_q.size());
                errors++;
            end
            if (m_valid !== (model_q.size() != 0)) begin
                $error("m_valid = %b with %0d entries", m_valid, model_q.size());
                errors++;
            end

            // First-word fall-through: whenever data is present, m_data
            // must already show the oldest word, whether or not it's read
            if (model_q.size() != 0 && m_data !== model_q[0]) begin
                $error("m_data = %h, expected %h", m_data, model_q[0]);
                errors++;
            end

            if (model_q.size() == DEPTH) full_cycles++;
            if (model_q.size() == 0)     empty_cycles++;

            // Update the model with whatever transfers happen at this edge
            if (m_valid === 1'b1 && m_ready === 1'b1 && model_q.size() != 0)
                void'(model_q.pop_front());
            if (s_valid === 1'b1 && s_ready === 1'b1)
                model_q.push_back(s_data);
        end
    end

    // ------------------------------------------------------------------
    // Driver tasks: all called at a negedge, all return at a negedge
    // ------------------------------------------------------------------

    // Offer one word and hold it until the FIFO accepts it
    task automatic write_word(input logic [WIDTH-1:0] data);
        s_valid = 1'b1;
        s_data  = data;
        // s_ready only changes after a posedge, so its value at this
        // negedge tells us whether the NEXT posedge will accept
        while (s_ready !== 1'b1) @(negedge clk);
        @(negedge clk);          // the posedge in between took it
        s_valid = 1'b0;
    endtask

    // Take one word; the scoreboard checks its value
    task automatic read_word();
        m_ready = 1'b1;
        while (m_valid !== 1'b1) @(negedge clk);
        @(negedge clk);
        m_ready = 1'b0;
    endtask

    // Check count and both flags at a known point
    task automatic expect_state(input string label, input int exp_count);
        if (count !== exp_count) begin
            $error("%s: count = %0d, expected %0d", label, count, exp_count);
            errors++;
        end
        if (s_ready !== (exp_count != DEPTH)) begin
            $error("%s: s_ready = %b", label, s_ready);
            errors++;
        end
        if (m_valid !== (exp_count != 0)) begin
            $error("%s: m_valid = %b", label, m_valid);
            errors++;
        end
    endtask

    // Random valid/ready each cycle. wr_pct and rd_pct are the percent
    // chance of offering a write / being ready to read on any cycle.
    task automatic random_traffic(input int cycles, input int wr_pct, input int rd_pct);
        logic accepted;
        accepted = 1'b1;
        for (int cyc = 0; cyc < cycles; cyc++) begin
            // A source may not withdraw or change a word that's still
            // waiting, so only pick a new one if the last was taken
            if (accepted || !s_valid) begin
                s_valid = ($urandom_range(0, 99) < wr_pct);
                s_data  = {$urandom(), $urandom()};
            end
            m_ready  = ($urandom_range(0, 99) < rd_pct);
            accepted = s_valid && s_ready;
            @(negedge clk);
        end
        // Don't withdraw a word that's still waiting
        m_ready = 1'b1;
        while (s_valid && !accepted) begin
            accepted = s_ready;
            @(negedge clk);
        end
        s_valid = 1'b0;
        m_ready = 1'b0;
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    initial begin
        rst     = 1'b1;
        s_valid = 1'b0;
        s_data  = '0;
        m_ready = 1'b0;
        repeat (5) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        $display("[%0t] Test 1: reset state", $time);
        expect_state("reset", 0);

        $display("[%0t] Test 2: fill to full", $time);
        for (int i = 0; i < DEPTH; i++)
            write_word(64'hF111_0000_0000_0000 + i);
        expect_state("after fill", DEPTH);

        $display("[%0t] Test 3: write while full is refused", $time);
        s_valid = 1'b1;
        s_data  = 64'hDEAD_BEEF_DEAD_BEEF;
        repeat (3) @(negedge clk);
        s_valid = 1'b0;
        expect_state("write while full", DEPTH);

        $display("[%0t] Test 4: drain to empty", $time);
        for (int i = 0; i < DEPTH; i++)
            read_word();
        expect_state("after drain", 0);

        $display("[%0t] Test 5: read while empty is refused", $time);
        m_ready = 1'b1;
        repeat (3) @(negedge clk);
        m_ready = 1'b0;
        expect_state("read while empty", 0);

        $display("[%0t] Test 6: simultaneous read + write", $time);
        for (int i = 0; i < 4; i++)
            write_word(64'h5111_0000_0000_0000 + i);
        s_valid = 1'b1;
        m_ready = 1'b1;
        for (int i = 0; i < 20; i++) begin
            s_data = 64'h5222_0000_0000_0000 + i;
            @(negedge clk);
            if (count !== 4) begin
                $error("simultaneous: count = %0d, expected 4", count);
                errors++;
            end
        end
        s_valid = 1'b0;
        m_ready = 1'b0;
        repeat (4) read_word();
        expect_state("after simultaneous", 0);

        $display("[%0t] Test 7: random traffic (write-heavy, then read-heavy)", $time);
        random_traffic(2000, 75, 25);
        random_traffic(2000, 25, 75);
        m_ready = 1'b1;
        while (m_valid === 1'b1) @(negedge clk);
        m_ready = 1'b0;
        expect_state("final drain", 0);

        $display("Cycles spent full: %0d, empty: %0d", full_cycles, empty_cycles);
        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end

    // Watchdog: if a bug makes a task wait forever, stop instead of hanging
    initial begin
        #(CLK_PERIOD * TIMEOUT_CYCLES);
        $fatal(1, "Timeout after %0d cycles", TIMEOUT_CYCLES);
    end

endmodule