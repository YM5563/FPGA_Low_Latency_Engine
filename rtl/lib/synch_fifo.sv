module synch_fifo #(
    parameter WIDTH = 64,
    parameter DEPTH = 16,
    localparam PTR_W = $clog2(DEPTH) - 1,
    localparam CNT_W = PTR_W + 1
)(
    input logic clk,
    input logic rst,

    //Write side signals
    input logic s_valid,
    input logic [WIDTH - 1 : 0] s_data,

    //read side ready flag
    input logic m_ready,

    //write side ready flag
    output logic s_ready,

    //read side signals
    output logic m_valid,
    output logic [WIDTH - 1 : 0] m_data,

    //count register
    output logic [CNT_W : 0] count

);

    logic [WIDTH - 1 : 0] mem_array [DEPTH - 1 : 0];
    logic [PTR_W : 0] wr_ptr_q;
    logic [PTR_W : 0] rd_ptr_q;
    logic [PTR_W : 0] wr_ptr_d;
    logic [PTR_W : 0] rd_ptr_d;

    //Write side handshake
    assign s_ready = count != DEPTH;
    logic write_handshake;
    assign write_handshake = s_ready && s_valid;

    //read side handshake
    assign m_valid  = count != 0;
    logic read_handshake;
    assign read_handshake = m_valid && m_ready;

    logic [1:0] handshake;
    assign handshake = {write_handshake, read_handshake};

    //count next 
    logic [CNT_W : 0] count_d;

    //Oldest data inside FIFO gets read
    assign m_data = mem_array[rd_ptr_q];

    always_comb begin
        wr_ptr_d = wr_ptr_q;
        rd_ptr_d = rd_ptr_q;
        count_d = count;
        case (handshake)
            //read
            2'b01 : begin
                rd_ptr_d = rd_ptr_q + 1'b1;
                count_d = count - 1'b1;
            end

            //write
            2'b10 : begin
                wr_ptr_d = wr_ptr_q + 1'b1;
                count_d = count + 1'b1;
            end

            //both - just dont update the count
            2'b11 : begin
                rd_ptr_d = rd_ptr_q + 1'b1;
                wr_ptr_d = wr_ptr_q + 1'b1;
            end

        endcase

    end

    //control signal sequential block
    always_ff @ (posedge clk) begin
        if (rst) begin
            count <= 0;
            wr_ptr_q <= 0;
            rd_ptr_q <= 0;
        end else  begin
            count <= count_d;
            wr_ptr_q <= wr_ptr_d;
            rd_ptr_q <= rd_ptr_d;
        end 
    end

    //memory reset free sequential block
    always_ff @(posedge clk) begin
        if (write_handshake) mem_array[wr_ptr_q] <= s_data;
    end


endmodule