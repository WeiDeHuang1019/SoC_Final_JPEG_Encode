//本模組為 AXI-Stream 資料延遲器，接收固定筆數後暫存，延遲處理並依序完整輸出，用於資料同步與驗證。

module axis_buffer_delay #(
    parameter DATA_WIDTH = 8,
    parameter BUFFER_SIZE = 768  // 預期接收 768 筆
)(
    input  wire                   aclk,
    input  wire                   aresetn,

    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,

    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast
);

    // FSM 狀態宣告
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_RECEIVE = 2'd1;
    localparam STATE_PROCESS = 2'd2;
    localparam STATE_SEND    = 2'd3;

    reg [1:0] state;

    // buffer
    reg [DATA_WIDTH-1:0] bufferIN  [0:BUFFER_SIZE-1];
    reg [DATA_WIDTH-1:0] bufferOUT [0:BUFFER_SIZE-1];
    reg [9:0] write_ptr;
    reg [9:0] read_ptr;
    reg [9:0] proc_index;
    reg [9:0] total_count;  // 實際接收資料筆數

    // AXIS IO
    assign s_axis_tready = (state == STATE_RECEIVE);
    assign m_axis_tvalid = (state == STATE_SEND);
    assign m_axis_tdata  = bufferOUT[read_ptr];
    assign m_axis_tlast  = (read_ptr == total_count - 1);

    // FSM 主流程
    always @(posedge aclk) begin
        if (!aresetn) begin
            state <= STATE_IDLE;
            write_ptr <= 0;
            read_ptr <= 0;
            proc_index <= 0;
            total_count <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    write_ptr <= 0;
                    read_ptr <= 0;
                    proc_index <= 0;
                    total_count <= 0;
                    state <= STATE_RECEIVE;
                end

                STATE_RECEIVE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        bufferIN[write_ptr] <= s_axis_tdata;
                        write_ptr <= write_ptr + 1;
                        total_count <= total_count + 1;
                        if (s_axis_tlast) begin
                            proc_index <= 0;
                            state <= STATE_PROCESS;
                        end
                    end
                end

                STATE_PROCESS: begin
                    bufferOUT[proc_index] <= bufferIN[proc_index];
                    proc_index <= proc_index + 1;
                    if (proc_index + 1 == total_count) begin
                        proc_index <= 0;
                        read_ptr <= 0;
                        state <= STATE_SEND;
                    end
                end

                STATE_SEND: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        read_ptr <= read_ptr + 1;
                        if (read_ptr + 1 == total_count) begin
                            state <= STATE_IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule
