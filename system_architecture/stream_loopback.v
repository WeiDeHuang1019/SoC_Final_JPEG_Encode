module stream_loopback #(
    parameter DATA_WIDTH = 32
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

    reg [DATA_WIDTH-1:0] buffer_data;
    reg                  buffer_last;
    reg                  buffer_valid;

    assign s_axis_tready = ~buffer_valid;
    assign m_axis_tvalid = buffer_valid;
    assign m_axis_tdata  = buffer_data;
    assign m_axis_tlast  = buffer_last;

    always @(posedge aclk) begin
        if (!aresetn) begin
            buffer_data  <= 0;
            buffer_last  <= 0;
            buffer_valid <= 0;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                buffer_data  <= s_axis_tdata;
                buffer_last  <= s_axis_tlast;
                buffer_valid <= 1;
            end else if (m_axis_tready && buffer_valid) begin
                buffer_valid <= 0;
            end
        end
    end

endmodule
