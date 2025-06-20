
module chroma_downsampling #(
    parameter DATA_WIDTH = 8,
    parameter BUFFER_SIZE = 768  // 預期接收 768 筆 (Y=256, Cb=256, Cr=256)
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
    localparam STATE_IDLE    = 3'd0;
    localparam STATE_RECEIVE = 3'd1;
    localparam STATE_PROCESS = 3'd2;
    localparam STATE_SEND    = 3'd3;

    reg [2:0] state;

    // buffer_y: 先存滿 256 筆 Y
    // buffer_cb: 先存滿 256 筆 Cb
    // buffer_cr: 先存滿 256 筆 Cr
    // process: y直接塞進 output buffer
    // process: cb與cr每拍做一個 2x2 平均，塞進 output buffer

    reg [DATA_WIDTH-1:0] buffer_y [0:255];
    reg [DATA_WIDTH-1:0] buffer_cb[0:255];
    reg [DATA_WIDTH-1:0] buffer_cr[0:255];
    reg [DATA_WIDTH-1:0] output_buf[0:383]; // 256 Y + 64 Cb + 64 Cr

    reg [9:0] in_ptr;
    reg [8:0] out_ptr;
    reg [9:0] proc_idx;
    
    wire [2:0] cb_row = (proc_idx - 256) >> 3;
    wire [2:0] cb_col = (proc_idx - 256) & 7;
    wire [9:0] cb_base = (cb_row * 16 + cb_col) << 1;
    
    wire [5:0] cr_row = ((proc_idx - 320) >> 3);
    wire [5:0] cr_col = ((proc_idx - 320) & 7);
    wire [9:0] cr_base = (cr_row * 16 + cr_col) << 1;

    reg [9:0] sum_cb;
    reg [9:0] sum_cr;

    // AXIS IO
    assign s_axis_tready = (state == STATE_RECEIVE);
    assign m_axis_tvalid = (state == STATE_SEND);
    assign m_axis_tdata  = output_buf[out_ptr];
    assign m_axis_tlast  = (out_ptr == 383);

    always @(posedge aclk) begin
        if (!aresetn) begin
            state <= STATE_IDLE;
            in_ptr <= 0;
            out_ptr <= 0;
            proc_idx <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    in_ptr <= 0;
                    out_ptr <= 0;
                    proc_idx <= 0;
                    state <= STATE_RECEIVE;
                end

                STATE_RECEIVE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        if (in_ptr < 256)
                            buffer_y[in_ptr] <= s_axis_tdata;
                        else if (in_ptr < 512)
                            buffer_cb[in_ptr - 256] <= s_axis_tdata;
                        else
                            buffer_cr[in_ptr - 512] <= s_axis_tdata;

                        in_ptr <= in_ptr + 1;

                        if (s_axis_tlast || in_ptr == 767)
                            state <= STATE_PROCESS;
                    end
                end

                STATE_PROCESS: begin
                    if (proc_idx < 256) begin
                        output_buf[proc_idx] <= buffer_y[proc_idx];
                        proc_idx <= proc_idx + 1;
                    end else if (proc_idx < 320) begin
                        // Cb downsample 2x2 (轉成 10-bit 加總避免 overflow)
                        sum_cb = {2'b00, buffer_cb[cb_base]} +
                                 {2'b00, buffer_cb[cb_base+1]} +
                                 {2'b00, buffer_cb[cb_base+16]} +
                                 {2'b00, buffer_cb[cb_base+17]};
                        output_buf[proc_idx] <= sum_cb >> 2;
                        proc_idx <= proc_idx + 1;
                    end else if (proc_idx < 384) begin
                        // Cr downsample 2x2 (轉成 10-bit 加總避免 overflow)
                        sum_cr = {2'b00, buffer_cr[cr_base]} +
                                 {2'b00, buffer_cr[cr_base+1]} +
                                 {2'b00, buffer_cr[cr_base+16]} +
                                 {2'b00, buffer_cr[cr_base+17]};
                        output_buf[proc_idx] <= sum_cr >> 2;
                        proc_idx <= proc_idx + 1;
                    end else begin
                        out_ptr <= 0;
                        state <= STATE_SEND;
                    end
                end


                STATE_SEND: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        if (out_ptr == 383)
                            state <= STATE_IDLE;
                        out_ptr <= out_ptr + 1;
                    end
                end
            endcase
        end
    end

endmodule
