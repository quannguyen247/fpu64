`ifndef FPU64_DEFS_VH
`define FPU64_DEFS_VH

`define F_ADD    4'd0
`define F_SUB    4'd1
`define F_MUL    4'd2
`define F_DIV    4'd3
`define F_SQRT   4'd4
`define F_SGNJ   4'd5
`define F_MINMAX 4'd6
`define F_CVT    4'd7
`define F_COMP   4'd8
`define F_CLASS  4'd9
`define F_MVTX   4'd10
`define F_MVXT   4'd11

`define RM_RNE   3'b000
`define RM_RTZ   3'b001
`define RM_RDN   3'b010
`define RM_RUP   3'b011
`define RM_RMM   3'b100

`define FF_NV    4
`define FF_DZ    3
`define FF_OF    2
`define FF_UF    1
`define FF_NX    0

`endif
