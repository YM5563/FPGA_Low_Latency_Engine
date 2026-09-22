module synch_fifi #(
    parameter WIDTH = 64,
    parameter DEPTH = 16
)(
    logic input clk,
    logic input rst_n,

    //Write side signals
    logic input s_valid,
    logic input [WIDTH - 1 : 0] s_data,

    //read side ready flag
    logic input m_ready,

    //write side ready flag
    logic output s_ready,

    //read side signals
    logic output m_valid,
    logic output [WIDTH - 1 : 0] m_data,

    //count register
    logic output [$clog2(DEPTH) : 0] count

);

    logic [WIDTH - 1 : 0] mem_array [DEPTH - 1 : 0];
    logic [$clog2(DEPTH) -1 : 0] wr_ptr;
    logic [$clog2(DEPTH) -1 : 0] rd_ptr;
    logic [$clog2(DEPTH) -1 : 0] wr_ptr_next;
    logic [$clog2(DEPTH) -1 : 0] rd_ptr_next;

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
    logic [$clog2(DEPTH) : 0] count_next;

    //Oldest data inside FIFO gets read
    assign m_data = mem_array[rd_ptr];

    //only read out the data if handshake is valid
    always_comb begin

        case (handshake)
            //read
            2'b01 : begin
                rd_ptr_next = rd_ptr + 1;
                count_next = count - 1;
            end

            //write
            2'b10 : begin
                wr_ptr_next = wr_ptr + 1;
                count_next = count + 1;
            end

            //both - just dont update the count
            2'b11 : begin
                rd_ptr_next = rd_ptr + 1;
                m_data = mem_array[rd_ptr];
                wr_ptr_next = wr_ptr + 1;
                count_next = count;
            end

            default : begin
                wr_ptr_next = wr_ptr;
                rd_ptr_next = rd_ptr;
                count_next = count;
                m_data = 0;
            end
        endcase

    end

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            count <= 0;
        end else if (write_handshake || read_handshake) begin
            if (write_handshake) begin
                //update memory array, write pointer and count
                mem_array[wr_ptr] <= s_data;
                wr_ptr <= wr_ptr_next;
                count <= count_next;
            end

            if (read_handshake) begin
                //update the read poitner and count
                rd_ptr <= rd_ptr_next;
                count <= count_next;
            end
        end 
    end


endmodule