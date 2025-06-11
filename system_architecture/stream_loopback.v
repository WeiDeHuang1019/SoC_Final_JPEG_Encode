module stream_loopback (
    input wire         aclk,
    input wire         aresetn,
    
    // AXI4-Stream Slave Interface
    input wire [31:0]  s_axis_tdata,
    input wire         s_axis_tvalid,
    output wire        s_axis_tready,
    input wire         s_axis_tlast,

    // AXI4-Stream Master Interface
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input wire         m_axis_tready,
    output wire        m_axis_tlast
);

assign s_axis_tready = m_axis_tready;
assign m_axis_tdata  = s_axis_tdata;
assign m_axis_tvalid = s_axis_tvalid;
assign m_axis_tlast  = s_axis_tlast;

endmodule
