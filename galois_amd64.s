//+build !noasm !appengine

// Copyright 2015, Klaus Post, see LICENSE for details.

// Based on http://www.snia.org/sites/default/files2/SDC2013/presentations/NewThinking/EthanMiller_Screaming_Fast_Galois_Field%20Arithmetic_SIMD%20Instructions.pdf
// and http://jerasure.org/jerasure/gf-complete/tree/master

// func galMulSSSE3Xor(low, high, in, out []byte)
TEXT ·galMulSSSE3Xor(SB), 7, $0
	MOVQ   low+0(FP), SI     // SI: &low
	MOVQ   high+24(FP), DX   // DX: &high
	MOVOU  (SI), X6          // X6 low
	MOVOU  (DX), X7          // X7: high
	MOVQ   $15, BX           // BX: low mask
	MOVQ   BX, X8
	PXOR   X5, X5
	MOVQ   in+48(FP), SI     // R11: &in
	MOVQ   in_len+56(FP), R9 // R9: len(in)
	MOVQ   out+72(FP), DX    // DX: &out
	PSHUFB X5, X8            // X8: lomask (unpacked)
	SHRQ   $4, R9            // len(in) / 16
	CMPQ   R9, $0
	JEQ    done_xor

loopback_xor:
	MOVOU  (SI), X0     // in[x]
	MOVOU  (DX), X4     // out[x]
	MOVOU  X0, X1       // in[x]
	MOVOU  X6, X2       // low copy
	MOVOU  X7, X3       // high copy
	PSRLQ  $4, X1       // X1: high input
	PAND   X8, X0       // X0: low input
	PAND   X8, X1       // X0: high input
	PSHUFB X0, X2       // X2: mul low part
	PSHUFB X1, X3       // X3: mul high part
	PXOR   X2, X3       // X3: Result
	PXOR   X4, X3       // X3: Result xor existing out
	MOVOU  X3, (DX)     // Store
	ADDQ   $16, SI      // in+=16
	ADDQ   $16, DX      // out+=16
	SUBQ   $1, R9
	JNZ    loopback_xor

done_xor:
	RET

// func galMulSSSE3(low, high, in, out []byte)
TEXT ·galMulSSSE3(SB), 7, $0
	MOVQ   low+0(FP), SI     // SI: &low
	MOVQ   high+24(FP), DX   // DX: &high
	MOVOU  (SI), X6          // X6 low
	MOVOU  (DX), X7          // X7: high
	MOVQ   $15, BX           // BX: low mask
	MOVQ   BX, X8
	PXOR   X5, X5
	MOVQ   in+48(FP), SI     // R11: &in
	MOVQ   in_len+56(FP), R9 // R9: len(in)
	MOVQ   out+72(FP), DX    // DX: &out
	PSHUFB X5, X8            // X8: lomask (unpacked)
	SHRQ   $4, R9            // len(in) / 16
	CMPQ   R9, $0
	JEQ    done

loopback:
	MOVOU  (SI), X0 // in[x]
	MOVOU  X0, X1   // in[x]
	MOVOU  X6, X2   // low copy
	MOVOU  X7, X3   // high copy
	PSRLQ  $4, X1   // X1: high input
	PAND   X8, X0   // X0: low input
	PAND   X8, X1   // X0: high input
	PSHUFB X0, X2   // X2: mul low part
	PSHUFB X1, X3   // X3: mul high part
	PXOR   X2, X3   // X3: Result
	MOVOU  X3, (DX) // Store
	ADDQ   $16, SI  // in+=16
	ADDQ   $16, DX  // out+=16
	SUBQ   $1, R9
	JNZ    loopback

done:
	RET

#define TMP0 Y7
#define TMP1 Y8

#define MASK Y9

#define LO1 Y14
#define HI1 Y15
#define XLO1 X14
#define XHI1 X15

#define LO2 Y12
#define HI2 Y13
#define XLO2 X12
#define XHI2 X13

#define LO3 Y10
#define HI3 Y11
#define XLO3 X10
#define XHI3 X11

#define LO4 Y16
#define HI4 Y17
#define XLO4 X16
#define XHI4 X17

// Macro to setup multiplication table
#define MULTABLE(arglo, arghi, xlo, xhi, ylo, yhi) \
	MOVQ        arglo, SI         \ // SI: &low
	MOVQ        arghi, DX         \ // DX: &high
	MOVOU       (SI), xlo         \ // XLO: low
	MOVOU       (DX), xhi         \ // XHI: high
	VINSERTI128 $1, xlo, ylo, ylo \ // low
	VINSERTI128 $1, xhi, yhi, yhi // high

// Macro to setup mask for multiplication
#define MULMASK \
	MOVQ         $15, BX  \ // BX: low mask
	MOVQ         BX, X5   \
	VPBROADCASTB X5, MASK // lomask (unpacked)

// Macro for polynomial multiply followed by addition
#define GFMULLXOR(ymm, lo, hi, res) \
	GFMULL(ymm, lo, hi)  \
	VPXOR res, TMP0, res

// Macro for polynomial multiply
#define GFMULL(ymm, lo, hi) \
	VPSRLQ  $4, ymm, TMP1    \ // TMP1: high input
	VPAND   MASK, ymm, TMP0  \ // TMP0: low input
	VPAND   MASK, TMP1, TMP1 \ // TMP1: high input
	VPSHUFB TMP0, lo, TMP0   \ // TMP0: mul low part
	VPSHUFB TMP1, hi, TMP1   \ // TMP1: mul high part
	VPXOR   TMP0, TMP1, TMP0 // TMP0: Result

// func galMulAVX2Xor(low, high, in, out []byte)
TEXT ·galMulAVX2Xor(SB), 7, $0
	MOVQ  in_len+56(FP), R9 // R9: len(in)
	SHRQ  $5, R9            // len(in) / 32
	TESTQ R9, R9
	JZ    done_xor_avx2

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULMASK

	MOVQ out+72(FP), DX // DX: &out
	MOVQ in+48(FP), SI  // SI: &in

loopback_xor_avx2:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4
	GFMULLXOR(Y0, LO1, HI1, Y4)
	VMOVDQU Y4, (DX)

	ADDQ $32, SI // in+=32
	ADDQ $32, DX // out+=32

	SUBQ $1, R9
	JNZ  loopback_xor_avx2

done_xor_avx2:
	VZEROUPPER
	RET

// func galMulAVX2(low, high, in, out []byte)
TEXT ·galMulAVX2(SB), 7, $0
	MOVQ  in_len+56(FP), R9 // R9: len(in)
	SHRQ  $5, R9            // len(in) / 32
	TESTQ R9, R9
	JZ    done_avx2

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULMASK

	MOVQ out+72(FP), DX // DX: &out
	MOVQ in+48(FP), SI  // SI: &in

loopback_avx2:
	VMOVDQU (SI), Y0
	GFMULL(Y0, LO1, HI1)
	VMOVDQU TMP0, (DX)

	ADDQ $32, SI // in+=32
	ADDQ $32, DX // out+=32

	SUBQ $1, R9
	JNZ  loopback_avx2

done_avx2:
	VZEROUPPER
	RET

// func sSE2XorSlice(in, out []byte)
TEXT ·sSE2XorSlice(SB), 7, $0
	MOVQ in+0(FP), SI     // SI: &in
	MOVQ in_len+8(FP), R9 // R9: len(in)
	MOVQ out+24(FP), DX   // DX: &out
	SHRQ $4, R9           // len(in) / 16
	CMPQ R9, $0
	JEQ  done_xor_sse2

loopback_xor_sse2:
	MOVOU (SI), X0          // in[x]
	MOVOU (DX), X1          // out[x]
	PXOR  X0, X1
	MOVOU X1, (DX)
	ADDQ  $16, SI           // in+=16
	ADDQ  $16, DX           // out+=16
	SUBQ  $1, R9
	JNZ   loopback_xor_sse2

done_xor_sse2:
	RET

// func galMulAVX2XorParallel2(low, high, in, out, in2 []byte)
TEXT ·galMulAVX2XorParallel2(SB), 7, $0
	MOVQ  in_len+56(FP), R9       // R9: len(in)
	SHRQ  $5, R9                  // len(in) / 32
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel2

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULMASK

	MOVQ out+72(FP), DX // DX: &out
	MOVQ in+48(FP), SI  // SI: &in
	MOVQ in2+96(FP), AX // AX: &in2

loopback_xor_avx2_parallel2:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4

	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU (AX), Y0
	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU Y4, (DX)

	ADDQ $32, SI // in+=32
	ADDQ $32, AX // in2+=32
	ADDQ $32, DX // out+=32

	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel2

done_xor_avx2_parallel2:
	VZEROUPPER
	RET

// func galMulAVX2XorParallel22(low, high, in, out, in2, out2, low2, high2 []byte)
TEXT ·galMulAVX2XorParallel22(SB), 7, $0
	MOVQ  in_len+56(FP), R9        // R9: len(in)
	SHRQ  $5, R9                   // len(in) / 32
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel22

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULTABLE(low2+144(FP), high2+168(FP), XLO2, XHI2, LO2, HI2)
	MULMASK

	MOVQ out+72(FP), DX   // DX: &out
	MOVQ in+48(FP), SI    // SI: &in
	MOVQ in2+96(FP), AX   // AX: &in2
	MOVQ out2+120(FP), BX // BX: &out2

loopback_xor_avx2_parallel22:
	VMOVDQU (DX), Y4
	VMOVDQU (BX), Y5

	VMOVDQU (SI), Y0
	VMOVDQU (AX), Y1

	GFMULLXOR(Y0, LO1, HI1, Y4)
	GFMULLXOR(Y1, LO1, HI1, Y4)

	GFMULLXOR(Y0, LO2, HI2, Y5)
	GFMULLXOR(Y1, LO2, HI2, Y5)

	VMOVDQU Y4, (DX)
	VMOVDQU Y5, (BX)

	ADDQ $32, SI // in+=32
	ADDQ $32, AX // in2+=32
	ADDQ $32, DX // out+=32
	ADDQ $32, BX // out2+=32

	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel22

done_xor_avx2_parallel22:
	VZEROUPPER
	RET

// func galMulAVX2XorParallel3(low, high, in, out, in2, in3 []byte)
TEXT ·galMulAVX2XorParallel3(SB), 7, $0
	MOVQ  in_len+56(FP), R9       // R9: len(in)
	SHRQ  $5, R9                  // len(in) / 32
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel3

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULMASK

	MOVQ out+72(FP), DX  // DX: &out
	MOVQ in+48(FP), SI   // SI: &in
	MOVQ in2+96(FP), AX  // AX: &in2
	MOVQ in3+120(FP), BX // BX: &in3

loopback_xor_avx2_parallel3:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4

	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU (AX), Y0
	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU (BX), Y0
	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU Y4, (DX)

	ADDQ $32, SI // in+=32
	ADDQ $32, AX // in2+=32
	ADDQ $32, BX // in3+=32
	ADDQ $32, DX // out+=32

	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel3

done_xor_avx2_parallel3:
	VZEROUPPER
	RET

// func galMulAVX2XorParallel33(low, high, in, out, in2, in3, out2, out3, low2, high2, low3, high3 []byte)
TEXT ·galMulAVX2XorParallel33(SB), 7, $0
	MOVQ  in_len+56(FP), R9        // R9: len(in)
	SHRQ  $5, R9                   // len(in) / 32
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel33

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULTABLE(low2+168(FP), high2+192(FP), XLO2, XHI2, LO2, HI2)
	MULTABLE(low3+216(FP), high3+240(FP), XLO3, XHI3, LO3, HI3)
	MULMASK

	MOVQ out+72(FP), DX    // DX: &out
	MOVQ in+48(FP), SI     // SI: &in
	MOVQ in2+96(FP), AX    // AX: &in2
	MOVQ in3+120(FP), BX   // BX: &in3
	MOVQ out2+120(FP), CX  // CX: &out2
	MOVQ out3+144(FP), R10 // R10: &out3

loopback_xor_avx2_parallel33:
	// NB Can use **SINGLE** register for output
	VMOVDQU (DX), Y4
	VMOVDQU (CX), Y5
	VMOVDQU (R10), Y6

	VMOVDQU (SI), Y0
	VMOVDQU (AX), Y1
	VMOVDQU (BX), Y2

	GFMULLXOR(Y0, LO1, HI1, Y4)
	GFMULLXOR(Y1, LO1, HI1, Y4)
	GFMULLXOR(Y2, LO1, HI1, Y4)

	GFMULLXOR(Y0, LO2, HI2, Y5)
	GFMULLXOR(Y1, LO2, HI2, Y5)
	GFMULLXOR(Y2, LO2, HI2, Y5)

	GFMULLXOR(Y0, LO3, HI3, Y6)
	GFMULLXOR(Y1, LO3, HI3, Y6)
	GFMULLXOR(Y2, LO3, HI3, Y6)

	VMOVDQU Y4, (DX)
	VMOVDQU Y5, (CX)
	VMOVDQU Y6, (R10)

	ADDQ $32, SI  // in+=32
	ADDQ $32, AX  // in2+=32
	ADDQ $32, BX  // in3+=32
	ADDQ $32, DX  // out+=32
	ADDQ $32, CX  // out2+=32
	ADDQ $32, R10 // out3+=32

	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel33

done_xor_avx2_parallel33:
	VZEROUPPER
	RET

// func galMulAVX2XorParallel4(low, high, in, out, in2, in3 []byte)
TEXT ·galMulAVX2XorParallel4(SB), 7, $0
	MOVQ  in_len+56(FP), R9       // R9: len(in)
	SHRQ  $5, R9                  // len(in) / 32
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel4

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULMASK

	MOVQ out+72(FP), DX  // DX: &out
	MOVQ in+48(FP), SI   // SI: &in
	MOVQ in2+96(FP), AX  // AX: &in2
	MOVQ in3+120(FP), BX // BX: &in3
	MOVQ in4+144(FP), CX // CX: &in4

loopback_xor_avx2_parallel4:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4

	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU (AX), Y0
	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU (BX), Y0
	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU (CX), Y0
	GFMULLXOR(Y0, LO1, HI1, Y4)

	VMOVDQU Y4, (DX)

	ADDQ $32, SI // in+=32
	ADDQ $32, AX // in2+=32
	ADDQ $32, BX // in3+=32
	ADDQ $32, CX // in4+=32
	ADDQ $32, DX // out+=32

	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel4

done_xor_avx2_parallel4:
	VZEROUPPER
	RET

// func galMulAVX2XorParallel44(low, high, in, out, in2, in3, in4, out2, out3, out4, low2, high2, low3, high3, low4, high4 []byte)
//                                0    24  48   72   96  120  144   168   192   216   240    264   288    312   336   360
TEXT ·galMulAVX2XorParallel44(SB), 7, $0
	MOVQ  in_len+56(FP), R9        // R9: len(in)
	SHRQ  $5, R9                   // len(in) / 32
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel44

	MULTABLE(low+0(FP), high+24(FP), XLO1, XHI1, LO1, HI1)
	MULTABLE(low2+240(FP), high2+264(FP), XLO2, XHI2, LO2, HI2)
	MULTABLE(low3+288(FP), high3+312(FP), XLO3, XHI3, LO3, HI3)

	// MULTABLE(low4+336(FP), high4+360(FP), XLO4, XHI4, LO4, HI4)
	MOVQ low4+336(FP), SI
	MOVQ high4+360(FP), DX
	LONG $0x48fde262; WORD $0x065a // VBROADCASTI64X2 ZMM16, [rsi]
	LONG $0x48fde262; WORD $0x0a5a // VBROADCASTI64X2 ZMM17, [rdx]

	MULMASK

	MOVQ out+72(FP), DX    // DX: &out
	MOVQ in+48(FP), SI     // SI: &in
	MOVQ in2+96(FP), AX    // AX: &in2
	MOVQ in3+120(FP), BX   // BX: &in3
	MOVQ out2+168(FP), CX  // CX: &out2
	MOVQ out3+192(FP), R10 // R10: &out3
	MOVQ in4+144(FP), R11  // R11: &in4
	MOVQ out4+216(FP), R12 // R12: &out4

loopback_xor_avx2_parallel44:
	VMOVDQU (SI), Y0
	VMOVDQU (AX), Y1
	VMOVDQU (BX), Y2
	VMOVDQU (R11), Y3

	VMOVDQU (DX), Y4
	VMOVDQU (CX), Y5
	VMOVDQU (R10), Y6

	LONG $0x28fec162; WORD $0x146f; BYTE $0x24 // VMOVDQU64 YMM18, [r12]

	GFMULLXOR(Y0, LO1, HI1, Y4)
	GFMULLXOR(Y1, LO1, HI1, Y4)
	GFMULLXOR(Y2, LO1, HI1, Y4)
	GFMULLXOR(Y3, LO1, HI1, Y4)

	GFMULLXOR(Y0, LO2, HI2, Y5)
	GFMULLXOR(Y1, LO2, HI2, Y5)
	GFMULLXOR(Y2, LO2, HI2, Y5)
	GFMULLXOR(Y3, LO2, HI2, Y5)

	GFMULLXOR(Y0, LO3, HI3, Y6)
	GFMULLXOR(Y1, LO3, HI3, Y6)
	GFMULLXOR(Y2, LO3, HI3, Y6)
	GFMULLXOR(Y3, LO3, HI3, Y6)

	// GFMULLXOR(Y0, LO4, HI4, Y18)
	LONG $0x20ddf162; WORD $0xd073; BYTE $0x04 // VPSRLQ   YMM20, YMM0, 4     ; Z1: high input
	LONG $0x28fdc162; WORD $0xd9db             // VPANDQ   YMM19, YMM0, YMM9  ; Z0: low input
	LONG $0x20ddc162; WORD $0xe1db             // VPANDQ   YMM20, YMM20, YMM9  ; Z1: high input
	LONG $0x207da262; WORD $0xdb00             // VPSHUFB  YMM19, YMM16, YMM19  ; Z2: mul low part
	LONG $0x2075a262; WORD $0xe400             // VPSHUFB  YMM20, YMM17, YMM20  ; Z3: mul high part
	LONG $0x20e5a162; WORD $0xdcef             // VPXORQ   YMM19, YMM19, YMM20  ; Z4: Result
	LONG $0x20eda162; WORD $0xd3ef             // VPXORQ   YMM18, YMM18, YMM19

	// GFMULLXOR(Y1, LO4, HI4, Y18)
	LONG $0x20ddf162; WORD $0xd173; BYTE $0x04 // VPSRLQ   YMM20, YMM1, 4     ; Z1: high input
	LONG $0x28f5c162; WORD $0xd9db             // VPANDQ   YMM19, YMM1, YMM9  ; Z0: low input
	LONG $0x20ddc162; WORD $0xe1db             // VPANDQ   YMM20, YMM20, YMM9  ; Z1: high input
	LONG $0x207da262; WORD $0xdb00             // VPSHUFB  YMM19, YMM16, YMM19  ; Z2: mul low part
	LONG $0x2075a262; WORD $0xe400             // VPSHUFB  YMM20, YMM17, YMM20  ; Z3: mul high part
	LONG $0x20e5a162; WORD $0xdcef             // VPXORQ   YMM19, YMM19, YMM20  ; Z4: Result
	LONG $0x20eda162; WORD $0xd3ef             // VPXORQ   YMM18, YMM18, YMM19

	// GFMULLXOR(Y2, LO4, HI4, Y18)
	LONG $0x20ddf162; WORD $0xd273; BYTE $0x04 // VPSRLQ   YMM20, YMM2, 4     ; Z1: high input
	LONG $0x28edc162; WORD $0xd9db             // VPANDQ   YMM19, YMM2, YMM9  ; Z0: low input
	LONG $0x20ddc162; WORD $0xe1db             // VPANDQ   YMM20, YMM20, YMM9  ; Z1: high input
	LONG $0x207da262; WORD $0xdb00             // VPSHUFB  YMM19, YMM16, YMM19  ; Z2: mul low part
	LONG $0x2075a262; WORD $0xe400             // VPSHUFB  YMM20, YMM17, YMM20  ; Z3: mul high part
	LONG $0x20e5a162; WORD $0xdcef             // VPXORQ   YMM19, YMM19, YMM20  ; Z4: Result
	LONG $0x20eda162; WORD $0xd3ef             // VPXORQ   YMM18, YMM18, YMM19

	// GFMULLXOR(Y3, LO4, HI4, Y18)
	LONG $0x20ddf162; WORD $0xd373; BYTE $0x04 // VPSRLQ   YMM20, YMM3, 4     ; Z1: high input
	LONG $0x28e5c162; WORD $0xd9db             // VPANDQ   YMM19, YMM3, YMM9  ; Z0: low input
	LONG $0x20ddc162; WORD $0xe1db             // VPANDQ   YMM20, YMM20, YMM9  ; Z1: high input
	LONG $0x207da262; WORD $0xdb00             // VPSHUFB  YMM19, YMM16, YMM19  ; Z2: mul low part
	LONG $0x2075a262; WORD $0xe400             // VPSHUFB  YMM20, YMM17, YMM20  ; Z3: mul high part
	LONG $0x20e5a162; WORD $0xdcef             // VPXORQ   YMM19, YMM19, YMM20  ; Z4: Result
	LONG $0x20eda162; WORD $0xd3ef             // VPXORQ   YMM18, YMM18, YMM19

	VMOVDQU Y4, (DX)
	VMOVDQU Y5, (CX)
	VMOVDQU Y6, (R10)

	LONG $0x28fec162; WORD $0x147f; BYTE $0x24 // VMOVDQU64 [r12], YMM18

	ADDQ $32, SI  // in+=32
	ADDQ $32, AX  // in2+=32
	ADDQ $32, BX  // in3+=32
	ADDQ $32, DX  // out+=32
	ADDQ $32, CX  // out2+=32
	ADDQ $32, R10 // out3+=32
	ADDQ $32, R11 // in4+=32
	ADDQ $32, R12 // out4+=32

	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel44

done_xor_avx2_parallel44:
	VZEROUPPER
	RET

// func galMulAVX512XorParallel44(low, high, in, out, in2, in3, in4, out2, out3, out4, low2, high2, low3, high3, low4, high4 []byte)
//                                  0    24  48   72   96  120  144   168   192   216   240    264   288    312   336   360
TEXT ·galMulAVX512XorParallel44(SB), 7, $0
	MOVQ  in_len+56(FP), R9        // R9: len(in)
	SHRQ  $6, R9                   // len(in) / 64
	TESTQ R9, R9
	JZ    done_xor_avx512_parallel44

	MOVQ low+0(FP), SI
	MOVQ high+24(FP), DX
	                 // VBROADCASTI64X2 ZMM14, [rsi]
	                 // VBROADCASTI64X2 ZMM15, [rdx]

	MOVQ low2+240(FP), SI
	MOVQ high2+264(FP), DX
	                 // VBROADCASTI64X2 ZMM12, [rsi]
	                 // VBROADCASTI64X2 ZMM13, [rdx]

	MOVQ low3+288(FP), SI
	MOVQ high3+312(FP), DX
	                 // VBROADCASTI64X2 ZMM10, [rsi]
	                 // VBROADCASTI64X2 ZMM11, [rdx]

	MOVQ low4+336(FP), SI
	MOVQ high4+360(FP), DX
	                 // VBROADCASTI64X2 ZMM16, [rsi]
	                 // VBROADCASTI64X2 ZMM17, [rdx]

	MOVQ         $15, BX
	MOVQ         BX, X5
	                 // VPBROADCASTB ZMM9, XMM5

	MOVQ out+72(FP), DX    // DX: &out
	MOVQ in+48(FP), SI     // SI: &in
	MOVQ in2+96(FP), AX    // AX: &in2
	MOVQ in3+120(FP), BX   // BX: &in3
	MOVQ out2+168(FP), CX  // CX: &out2
	MOVQ out3+192(FP), R10 // R10: &out3
	MOVQ in4+144(FP), R11  // R11: &in4
	MOVQ out4+216(FP), R12 // R12: &out4

loopback_xor_avx512_parallel44:
	                 // VMOVDQU64 ZMM0, [rsi]
	                 // VMOVDQU64 ZMM1, [rax]
	                 // VMOVDQU64 ZMM2, [rbx]
	                 // VMOVDQU64 ZMM3, [r11]

	                 // VMOVDQU64 ZMM4, [rdx]
	                 // VMOVDQU64 ZMM5, [rcx]
	                 // VMOVDQU64 ZMM6, [r10]
	                 // VMOVDQU64 ZMM18, [r12]

	                 // VPSRLQ   ZMM20, ZMM0, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM0, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM14, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM15, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM4, ZMM4, ZMM19

	                 // VPSRLQ   ZMM20, ZMM1, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM1, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM14, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM15, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM4, ZMM4, ZMM19

	                 // VPSRLQ   ZMM20, ZMM2, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM2, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM14, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM15, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM4, ZMM4, ZMM19

	                 // VPSRLQ   ZMM20, ZMM3, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM3, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM14, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM15, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM4, ZMM4, ZMM19

	                 // VPSRLQ   ZMM20, ZMM0, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM0, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM12, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM13, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM5, ZMM5, ZMM19

	                 // VPSRLQ   ZMM20, ZMM1, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM1, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM12, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM13, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM5, ZMM5, ZMM19

	                 // VPSRLQ   ZMM20, ZMM2, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM2, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM12, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM13, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM5, ZMM5, ZMM19

	                 // VPSRLQ   ZMM20, ZMM3, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM3, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM12, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM13, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM5, ZMM5, ZMM19

	                 // VPSRLQ   ZMM20, ZMM0, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM0, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM10, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM11, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM6, ZMM6, ZMM19

	                 // VPSRLQ   ZMM20, ZMM1, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM1, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM10, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM11, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM6, ZMM6, ZMM19

	                 // VPSRLQ   ZMM20, ZMM2, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM2, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM10, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM11, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM6, ZMM6, ZMM19

	                 // VPSRLQ   ZMM20, ZMM3, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM3, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM10, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM11, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM6, ZMM6, ZMM19

	                 // VPSRLQ   ZMM20, ZMM0, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM0, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM16, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM17, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM18, ZMM18, ZMM19

	                 // VPSRLQ   ZMM20, ZMM1, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM1, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM16, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM17, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM18, ZMM18, ZMM19

	                 // VPSRLQ   ZMM20, ZMM2, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM2, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM16, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM17, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM18, ZMM18, ZMM19

	                 // VPSRLQ   ZMM20, ZMM3, 4     ; high input
	                 // VPANDQ   ZMM19, ZMM3, ZMM9  ; low input
	                 // VPANDQ   ZMM20, ZMM20, ZMM9  ; high input
	                 // VPSHUFB  ZMM19, ZMM16, ZMM19  ; mul low part
	                 // VPSHUFB  ZMM20, ZMM17, ZMM20  ; mul high part
	                 // VPXORQ   ZMM19, ZMM19, ZMM20  ; result
	                 // VPXORQ   ZMM18, ZMM18, ZMM19

	                 // VMOVDQU64 [rdx], ZMM4
	                 // VMOVDQU64 [rcx], ZMM5
	                 // VMOVDQU64 [r10], ZMM6
	                 // VMOVDQU64 [r12], ZMM18

	ADDQ $64, SI  // in+=64
	ADDQ $64, AX  // in2+=64
	ADDQ $64, BX  // in3+=64
	ADDQ $64, DX  // out+=64
	ADDQ $64, CX  // out2+=64
	ADDQ $64, R10 // out3+=64
	ADDQ $64, R11 // in4+=64
	ADDQ $64, R12 // out4+=64

	SUBQ $1, R9
	JNZ  loopback_xor_avx512_parallel44

done_xor_avx512_parallel44:
	VZEROUPPER
	RET

// func galMulAVX512Parallel84(in, out [][]byte, matrix []byte, clear bool) (done int64)
//                              0   24           48             72           80
TEXT ·galMulAVX512Parallel84(SB), 7, $0
	MOVQ  in+0(FP), SI     //
	MOVQ  8(SI), R9        // R9: len(in)
	SHRQ  $6, R9           // len(in) / 64
	TESTQ R9, R9
	JZ    done_avx512_parallel84

	MOVQ matrix+48(FP), SI
	LONG $0x48fee162; WORD $0x066f // VMOVDQU64 ZMM16, 0x000[rsi]
	LONG $0x48fee162; WORD $0x4e6f; BYTE $0x01 // VMOVDQU64 ZMM17, 0x040[rsi]
	LONG $0x48fee162; WORD $0x566f; BYTE $0x02 // VMOVDQU64 ZMM18, 0x080[rsi]
	LONG $0x48fee162; WORD $0x5e6f; BYTE $0x03 // VMOVDQU64 ZMM19, 0x0c0[rsi]
	LONG $0x48fee162; WORD $0x666f; BYTE $0x04 // VMOVDQU64 ZMM20, 0x100[rsi]
	LONG $0x48fee162; WORD $0x6e6f; BYTE $0x05 // VMOVDQU64 ZMM21, 0x140[rsi]
	LONG $0x48fee162; WORD $0x766f; BYTE $0x06 // VMOVDQU64 ZMM22, 0x180[rsi]
	LONG $0x48fee162; WORD $0x7e6f; BYTE $0x07 // VMOVDQU64 ZMM23, 0x1c0[rsi]
	LONG $0x48fe6162; WORD $0x466f; BYTE $0x08 // VMOVDQU64 ZMM24, 0x200[rsi]
	LONG $0x48fe6162; WORD $0x4e6f; BYTE $0x09 // VMOVDQU64 ZMM25, 0x240[rsi]
	LONG $0x48fe6162; WORD $0x566f; BYTE $0x0a // VMOVDQU64 ZMM26, 0x280[rsi]
	LONG $0x48fe6162; WORD $0x5e6f; BYTE $0x0b // VMOVDQU64 ZMM27, 0x2c0[rsi]
	LONG $0x48fe6162; WORD $0x666f; BYTE $0x0c // VMOVDQU64 ZMM28, 0x300[rsi]
	LONG $0x48fe6162; WORD $0x6e6f; BYTE $0x0d // VMOVDQU64 ZMM29, 0x340[rsi]
	LONG $0x48fe6162; WORD $0x766f; BYTE $0x0e // VMOVDQU64 ZMM30, 0x380[rsi]
	LONG $0x48fe6162; WORD $0x7e6f; BYTE $0x0f // VMOVDQU64 ZMM31, 0x3c0[rsi]

	MOVQ         $15, BX
	MOVQ         BX, X5
	LONG $0x487df262; WORD $0xd578 // VPBROADCASTB ZMM2, XMM5

	MOVB xor+72(FP), AX
	LONG $0xffc0c749; WORD $0xffff; BYTE $0xff // mov r8, -1
	WORD $0xf749; BYTE $0xe0 // mul r8
	LONG $0x92fbe1c4; BYTE $0xc8 // kmovq k1, rax
	MOVQ in+0(FP), SI  //  SI: &in
	MOVQ 24(SI), AX    //  AX: &in[1][0]
	MOVQ 48(SI), BX    //  BX: &in[2][0]
	MOVQ 72(SI), R11   // R11: &in[3][0]
	MOVQ 96(SI), R13   // R13: &in[4][0]
	MOVQ 120(SI), R14  // R14: &in[5][0]
	MOVQ 144(SI), R15  // R15: &in[6][0]
	MOVQ 168(SI), R8   //  R8: &in[7][0]
	MOVQ (SI), SI      //  SI: &in[0][0]
	MOVQ out+24(FP), DX
	MOVQ 24(DX), CX    //  CX: &out[1][0]
	MOVQ 48(DX), R10   // R10: &out[2][0]
	MOVQ 72(DX), R12   // R12: &out[3][0]
	MOVQ (DX), DX      //  DX: &out[0][0]

loopback_avx512_parallel84:
	LONG $0xc9fef162; WORD $0x226f // VMOVDQU64 ZMM4{k1}{z}, [rdx]
	LONG $0xc9fef162; WORD $0x296f // VMOVDQU64 ZMM5{k1}{z}, [rcx]
	LONG $0xc9fed162; WORD $0x326f // VMOVDQU64 ZMM6{k1}{z}, [r10]
	LONG $0xc9fed162; WORD $0x3c6f; BYTE $0x24 // VMOVDQU64 ZMM7{k1}{z}, [r12]

	LONG $0x48fef162; WORD $0x066f // VMOVDQU64 ZMM0, [rsi]
	LONG $0x40fd3362; WORD $0xf043; BYTE $0x00 // VSHUFI64x2 ZMM14, ZMM16, ZMM16, 0x00
	LONG $0x40fd3362; WORD $0xf843; BYTE $0x55 // VSHUFI64x2 ZMM15, ZMM16, ZMM16, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40dd3362; WORD $0xe443; BYTE $0x00 // VSHUFI64x2 ZMM12, ZMM20, ZMM20, 0x00
	LONG $0x40dd3362; WORD $0xec43; BYTE $0x55 // VSHUFI64x2 ZMM13, ZMM20, ZMM20, 0x55
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40bd1362; WORD $0xd043; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM24, ZMM24, 0x00
	LONG $0x40bd1362; WORD $0xd843; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM24, ZMM24, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x409d1362; WORD $0xc443; BYTE $0x00 // VSHUFI64x2 ZMM8, ZMM28, ZMM28, 0x00
	LONG $0x409d1362; WORD $0xcc43; BYTE $0x55 // VSHUFI64x2 ZMM9, ZMM28, ZMM28, 0x55
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fef162; WORD $0x006f // VMOVDQU64 ZMM0, [rax]
	LONG $0x40fd3362; WORD $0xf043; BYTE $0xaa // VSHUFI64x2 ZMM14, ZMM16, ZMM16, 0xaa
	LONG $0x40fd3362; WORD $0xf843; BYTE $0xff // VSHUFI64x2 ZMM15, ZMM16, ZMM16, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40dd3362; WORD $0xe443; BYTE $0xaa // VSHUFI64x2 ZMM12, ZMM20, ZMM20, 0xaa
	LONG $0x40dd3362; WORD $0xec43; BYTE $0xff // VSHUFI64x2 ZMM13, ZMM20, ZMM20, 0xff
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40bd1362; WORD $0xd043; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM24, ZMM24, 0xaa
	LONG $0x40bd1362; WORD $0xd843; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM24, ZMM24, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x409d1362; WORD $0xc443; BYTE $0xaa // VSHUFI64x2 ZMM8, ZMM28, ZMM28, 0xaa
	LONG $0x409d1362; WORD $0xcc43; BYTE $0xff // VSHUFI64x2 ZMM9, ZMM28, ZMM28, 0xff
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fef162; WORD $0x036f // VMOVDQU64 ZMM0, [rbx]
	LONG $0x40f53362; WORD $0xf143; BYTE $0x00 // VSHUFI64x2 ZMM14, ZMM17, ZMM17, 0x00
	LONG $0x40f53362; WORD $0xf943; BYTE $0x55 // VSHUFI64x2 ZMM15, ZMM17, ZMM17, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40d53362; WORD $0xe543; BYTE $0x00 // VSHUFI64x2 ZMM12, ZMM21, ZMM21, 0x00
	LONG $0x40d53362; WORD $0xed43; BYTE $0x55 // VSHUFI64x2 ZMM13, ZMM21, ZMM21, 0x55
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40b51362; WORD $0xd143; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM25, ZMM25, 0x00
	LONG $0x40b51362; WORD $0xd943; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM25, ZMM25, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40951362; WORD $0xc543; BYTE $0x00 // VSHUFI64x2 ZMM8, ZMM29, ZMM29, 0x00
	LONG $0x40951362; WORD $0xcd43; BYTE $0x55 // VSHUFI64x2 ZMM9, ZMM29, ZMM29, 0x55
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fed162; WORD $0x036f // VMOVDQU64 ZMM0, [r11]
	LONG $0x40f53362; WORD $0xf143; BYTE $0xaa // VSHUFI64x2 ZMM14, ZMM17, ZMM17, 0xaa
	LONG $0x40f53362; WORD $0xf943; BYTE $0xff // VSHUFI64x2 ZMM15, ZMM17, ZMM17, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40d53362; WORD $0xe543; BYTE $0xaa // VSHUFI64x2 ZMM12, ZMM21, ZMM21, 0xaa
	LONG $0x40d53362; WORD $0xed43; BYTE $0xff // VSHUFI64x2 ZMM13, ZMM21, ZMM21, 0xff
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40b51362; WORD $0xd143; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM25, ZMM25, 0xaa
	LONG $0x40b51362; WORD $0xd943; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM25, ZMM25, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40951362; WORD $0xc543; BYTE $0xaa // VSHUFI64x2 ZMM8, ZMM29, ZMM29, 0xaa
	LONG $0x40951362; WORD $0xcd43; BYTE $0xff // VSHUFI64x2 ZMM9, ZMM29, ZMM29, 0xff
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fed162; WORD $0x456f; BYTE $0x00 // VMOVDQU64 ZMM0, [r13]
	LONG $0x40ed3362; WORD $0xf243; BYTE $0x00 // VSHUFI64x2 ZMM14, ZMM18, ZMM18, 0x00
	LONG $0x40ed3362; WORD $0xfa43; BYTE $0x55 // VSHUFI64x2 ZMM15, ZMM18, ZMM18, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40cd3362; WORD $0xe643; BYTE $0x00 // VSHUFI64x2 ZMM12, ZMM22, ZMM22, 0x00
	LONG $0x40cd3362; WORD $0xee43; BYTE $0x55 // VSHUFI64x2 ZMM13, ZMM22, ZMM22, 0x55
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40ad1362; WORD $0xd243; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM26, ZMM26, 0x00
	LONG $0x40ad1362; WORD $0xda43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM26, ZMM26, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x408d1362; WORD $0xc643; BYTE $0x00 // VSHUFI64x2 ZMM8, ZMM30, ZMM30, 0x00
	LONG $0x408d1362; WORD $0xce43; BYTE $0x55 // VSHUFI64x2 ZMM9, ZMM30, ZMM30, 0x55
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fed162; WORD $0x066f // VMOVDQU64 ZMM0, [r14]
	LONG $0x40ed3362; WORD $0xf243; BYTE $0xaa // VSHUFI64x2 ZMM14, ZMM18, ZMM18, 0xaa
	LONG $0x40ed3362; WORD $0xfa43; BYTE $0xff // VSHUFI64x2 ZMM15, ZMM18, ZMM18, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40cd3362; WORD $0xe643; BYTE $0xaa // VSHUFI64x2 ZMM12, ZMM22, ZMM22, 0xaa
	LONG $0x40cd3362; WORD $0xee43; BYTE $0xff // VSHUFI64x2 ZMM13, ZMM22, ZMM22, 0xff
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40ad1362; WORD $0xd243; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM26, ZMM26, 0xaa
	LONG $0x40ad1362; WORD $0xda43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM26, ZMM26, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x408d1362; WORD $0xc643; BYTE $0xaa // VSHUFI64x2 ZMM8, ZMM30, ZMM30, 0xaa
	LONG $0x408d1362; WORD $0xce43; BYTE $0xff // VSHUFI64x2 ZMM9, ZMM30, ZMM30, 0xff
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fed162; WORD $0x076f // VMOVDQU64 ZMM0, [r15]
	LONG $0x40e53362; WORD $0xf343; BYTE $0x00 // VSHUFI64x2 ZMM14, ZMM19, ZMM19, 0x00
	LONG $0x40e53362; WORD $0xfb43; BYTE $0x55 // VSHUFI64x2 ZMM15, ZMM19, ZMM19, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40c53362; WORD $0xe743; BYTE $0x00 // VSHUFI64x2 ZMM12, ZMM23, ZMM23, 0x00
	LONG $0x40c53362; WORD $0xef43; BYTE $0x55 // VSHUFI64x2 ZMM13, ZMM23, ZMM23, 0x55
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40a51362; WORD $0xd343; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM27, ZMM27, 0x00
	LONG $0x40a51362; WORD $0xdb43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM27, ZMM27, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40851362; WORD $0xc743; BYTE $0x00 // VSHUFI64x2 ZMM8, ZMM31, ZMM31, 0x00
	LONG $0x40851362; WORD $0xcf43; BYTE $0x55 // VSHUFI64x2 ZMM9, ZMM31, ZMM31, 0x55
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fed162; WORD $0x006f // VMOVDQU64 ZMM0, [r8]
	LONG $0x40e53362; WORD $0xf343; BYTE $0xaa // VSHUFI64x2 ZMM14, ZMM19, ZMM19, 0xaa
	LONG $0x40e53362; WORD $0xfb43; BYTE $0xff // VSHUFI64x2 ZMM15, ZMM19, ZMM19, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x480d7262; WORD $0xf000 // VPSHUFB  ZMM14, ZMM14, ZMM0  ; mul low part
	LONG $0x48057262; WORD $0xf900 // VPSHUFB  ZMM15, ZMM15, ZMM1  ; mul high part
	LONG $0x488d5162; WORD $0xf7ef // VPXORQ   ZMM14, ZMM14, ZMM15  ; result
	LONG $0x48ddd162; WORD $0xe6ef // VPXORQ   ZMM4, ZMM4, ZMM14

	LONG $0x40c53362; WORD $0xe743; BYTE $0xaa // VSHUFI64x2 ZMM12, ZMM23, ZMM23, 0xaa
	LONG $0x40c53362; WORD $0xef43; BYTE $0xff // VSHUFI64x2 ZMM13, ZMM23, ZMM23, 0xff
	LONG $0x481d7262; WORD $0xe000 // VPSHUFB  ZMM12, ZMM12, ZMM0  ; mul low part
	LONG $0x48157262; WORD $0xe900 // VPSHUFB  ZMM13, ZMM13, ZMM1  ; mul high part
	LONG $0x489d5162; WORD $0xe5ef // VPXORQ   ZMM12, ZMM12, ZMM13  ; result
	LONG $0x48d5d162; WORD $0xecef // VPXORQ   ZMM5, ZMM5, ZMM12

	LONG $0x40a51362; WORD $0xd343; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM27, ZMM27, 0xaa
	LONG $0x40a51362; WORD $0xdb43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM27, ZMM27, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40851362; WORD $0xc743; BYTE $0xaa // VSHUFI64x2 ZMM8, ZMM31, ZMM31, 0xaa
	LONG $0x40851362; WORD $0xcf43; BYTE $0xff // VSHUFI64x2 ZMM9, ZMM31, ZMM31, 0xff
	LONG $0x483d7262; WORD $0xc000 // VPSHUFB  ZMM8, ZMM8, ZMM0  ; mul low part
	LONG $0x48357262; WORD $0xc900 // VPSHUFB  ZMM9, ZMM9, ZMM1  ; mul high part
	LONG $0x48bd5162; WORD $0xc1ef // VPXORQ   ZMM8, ZMM8, ZMM9  ; result
	LONG $0x48c5d162; WORD $0xf8ef // VPXORQ   ZMM7, ZMM7, ZMM8

	LONG $0x48fef162; WORD $0x227f // VMOVDQU64 [rdx], ZMM4
	LONG $0x48fef162; WORD $0x297f // VMOVDQU64 [rcx], ZMM5
	LONG $0x48fed162; WORD $0x327f // VMOVDQU64 [r10], ZMM6
	LONG $0x48fed162; WORD $0x3c7f; BYTE $0x24 // VMOVDQU64 [r12], ZMM7

	ADDQ $64, SI  // in+=64
	ADDQ $64, AX  // in2+=64
	ADDQ $64, BX  // in3+=64
	ADDQ $64, DX  // out+=64
	ADDQ $64, CX  // out2+=64
	ADDQ $64, R10 // out3+=64
	ADDQ $64, R11 // in4+=64
	ADDQ $64, R12 // out4+=64
	ADDQ $64, R13 // in5+=64
	ADDQ $64, R14 // in6+=64
	ADDQ $64, R15 // in7+=64
	ADDQ $64, R8 // in8+=64

	SUBQ $1, R9
	JNZ  loopback_avx512_parallel84

done_avx512_parallel84:
	VZEROUPPER
	RET

TEXT ·galMulAVX512Parallel66(SB), 7, $0
	MOVQ  in+0(FP), SI     //
	MOVQ  8(SI), R9        // R9: len(in)
	SHRQ  $6, R9           // len(in) / 64
	TESTQ R9, R9
	JZ    done_avx512_parallel66

	MOVQ matrix+48(FP), SI
	LONG $0x48fe7162; WORD $0x366f // VMOVDQU64 ZMM14, 0x000[rsi]
	LONG $0x48fe7162; WORD $0x7e6f; BYTE $0x01 // VMOVDQU64 ZMM15, 0x040[rsi]
	LONG $0x48fee162; WORD $0x466f; BYTE $0x02 // VMOVDQU64 ZMM16, 0x080[rsi]
	LONG $0x48fee162; WORD $0x4e6f; BYTE $0x03 // VMOVDQU64 ZMM17, 0x0c0[rsi]
	LONG $0x48fee162; WORD $0x566f; BYTE $0x04 // VMOVDQU64 ZMM18, 0x100[rsi]
	LONG $0x48fee162; WORD $0x5e6f; BYTE $0x05 // VMOVDQU64 ZMM19, 0x140[rsi]
	LONG $0x48fee162; WORD $0x666f; BYTE $0x06 // VMOVDQU64 ZMM20, 0x180[rsi]
	LONG $0x48fee162; WORD $0x6e6f; BYTE $0x07 // VMOVDQU64 ZMM21, 0x1c0[rsi]
	LONG $0x48fee162; WORD $0x766f; BYTE $0x08 // VMOVDQU64 ZMM22, 0x200[rsi]
	LONG $0x48fee162; WORD $0x7e6f; BYTE $0x09 // VMOVDQU64 ZMM23, 0x240[rsi]
	LONG $0x48fe6162; WORD $0x466f; BYTE $0x0a // VMOVDQU64 ZMM24, 0x280[rsi]
	LONG $0x48fe6162; WORD $0x4e6f; BYTE $0x0b // VMOVDQU64 ZMM25, 0x2c0[rsi]
	LONG $0x48fe6162; WORD $0x566f; BYTE $0x0c // VMOVDQU64 ZMM26, 0x300[rsi]
	LONG $0x48fe6162; WORD $0x5e6f; BYTE $0x0d // VMOVDQU64 ZMM27, 0x340[rsi]
	LONG $0x48fe6162; WORD $0x666f; BYTE $0x0e // VMOVDQU64 ZMM28, 0x380[rsi]
	LONG $0x48fe6162; WORD $0x6e6f; BYTE $0x0f // VMOVDQU64 ZMM29, 0x3c0[rsi]
	LONG $0x48fe6162; WORD $0x766f; BYTE $0x10 // VMOVDQU64 ZMM30, 0x400[rsi]
	LONG $0x48fe6162; WORD $0x7e6f; BYTE $0x11 // VMOVDQU64 ZMM31, 0x440[rsi]

	MOVQ         $15, BX
	MOVQ         BX, X5
	LONG $0x487df262; WORD $0xd578 // VPBROADCASTB ZMM2, XMM5

	MOVB xor+72(FP), AX
	LONG $0xffc0c749; WORD $0xffff; BYTE $0xff // mov r8, -1
	WORD $0xf749; BYTE $0xe0 // mul r8
	LONG $0x92fbe1c4; BYTE $0xc8 // kmovq k1, rax
	MOVQ in+0(FP), SI  //  SI: &in
	MOVQ 24(SI), AX    //  AX: &in[1][0]
	MOVQ 48(SI), BX    //  BX: &in[2][0]
	MOVQ 72(SI), R11   // R11: &in[3][0]
	MOVQ 96(SI), R13   // R13: &in[4][0]
	MOVQ 120(SI), R14  // R14: &in[5][0]
	MOVQ (SI), SI      //  SI: &in[0][0]
	MOVQ out+24(FP), DX
	MOVQ 24(DX), CX    //  CX: &out[1][0]
	MOVQ 48(DX), R10   // R10: &out[2][0]
	MOVQ 72(DX), R12   // R12: &out[3][0]
	MOVQ 96(DX), R15   // R15: &out[4][0]
	MOVQ 120(DX), R8   //  R8: &out[5][0]
	MOVQ (DX), DX      //  DX: &out[0][0]

loopback_avx512_parallel66:
	LONG $0xc9fef162; WORD $0x226f // VMOVDQU64 ZMM4{k1}{z}, [rdx]
	LONG $0xc9fef162; WORD $0x296f // VMOVDQU64 ZMM5{k1}{z}, [rcx]
	LONG $0xc9fed162; WORD $0x326f // VMOVDQU64 ZMM6{k1}{z}, [r10]
	LONG $0xc9fed162; WORD $0x3c6f; BYTE $0x24 // VMOVDQU64 ZMM7{k1}{z}, [r12]
	LONG $0xc9fe5162; WORD $0x076f // VMOVDQU64 ZMM8{k1}{z}, [r15]
	LONG $0xc9fe5162; WORD $0x086f // VMOVDQU64 ZMM9{k1}{z}, [r8]

	LONG $0x48fef162; WORD $0x066f // VMOVDQU64 ZMM0, [rsi]
	LONG $0x488d5362; WORD $0xd643; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM14, ZMM14, 0x00
	LONG $0x488d5362; WORD $0xde43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM14, ZMM14, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40f53362; WORD $0xd143; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM17, ZMM17, 0x00
	LONG $0x40f53362; WORD $0xd943; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM17, ZMM17, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40dd3362; WORD $0xd443; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM20, ZMM20, 0x00
	LONG $0x40dd3362; WORD $0xdc43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM20, ZMM20, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40c53362; WORD $0xd743; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM23, ZMM23, 0x00
	LONG $0x40c53362; WORD $0xdf43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM23, ZMM23, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40ad1362; WORD $0xd243; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM26, ZMM26, 0x00
	LONG $0x40ad1362; WORD $0xda43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM26, ZMM26, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x40951362; WORD $0xd543; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM29, ZMM29, 0x00
	LONG $0x40951362; WORD $0xdd43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM29, ZMM29, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x48fef162; WORD $0x006f // VMOVDQU64 ZMM0, [rax]
	LONG $0x488d5362; WORD $0xd643; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM14, ZMM14, 0xaa
	LONG $0x488d5362; WORD $0xde43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM14, ZMM14, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40f53362; WORD $0xd143; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM17, ZMM17, 0xaa
	LONG $0x40f53362; WORD $0xd943; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM17, ZMM17, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40dd3362; WORD $0xd443; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM20, ZMM20, 0xaa
	LONG $0x40dd3362; WORD $0xdc43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM20, ZMM20, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40c53362; WORD $0xd743; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM23, ZMM23, 0xaa
	LONG $0x40c53362; WORD $0xdf43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM23, ZMM23, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40ad1362; WORD $0xd243; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM26, ZMM26, 0x00
	LONG $0x40ad1362; WORD $0xda43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM26, ZMM26, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x40951362; WORD $0xd543; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM29, ZMM29, 0x00
	LONG $0x40951362; WORD $0xdd43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM29, ZMM29, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x48fef162; WORD $0x036f // VMOVDQU64 ZMM0, [rbx]
	LONG $0x48855362; WORD $0xd743; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM15, ZMM15, 0x00
	LONG $0x48855362; WORD $0xdf43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM15, ZMM15, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40ed3362; WORD $0xd243; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM18, ZMM18, 0x00
	LONG $0x40ed3362; WORD $0xda43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM18, ZMM18, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40d53362; WORD $0xd543; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM21, ZMM21, 0x00
	LONG $0x40d53362; WORD $0xdd43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM21, ZMM21, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40bd1362; WORD $0xd043; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM24, ZMM24, 0x00
	LONG $0x40bd1362; WORD $0xd843; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM24, ZMM24, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40a51362; WORD $0xd343; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM27, ZMM27, 0x00
	LONG $0x40a51362; WORD $0xdb43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM27, ZMM27, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x408d1362; WORD $0xd643; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM30, ZMM30, 0x00
	LONG $0x408d1362; WORD $0xde43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM30, ZMM30, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x48fed162; WORD $0x036f // VMOVDQU64 ZMM0, [r11]
	LONG $0x48855362; WORD $0xd743; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM15, ZMM15, 0xaa
	LONG $0x48855362; WORD $0xdf43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM15, ZMM15, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40ed3362; WORD $0xd243; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM18, ZMM18, 0xaa
	LONG $0x40ed3362; WORD $0xda43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM18, ZMM18, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40d53362; WORD $0xd543; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM21, ZMM21, 0xaa
	LONG $0x40d53362; WORD $0xdd43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM21, ZMM21, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40bd1362; WORD $0xd043; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM24, ZMM24, 0xaa
	LONG $0x40bd1362; WORD $0xd843; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM24, ZMM24, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40a51362; WORD $0xd343; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM27, ZMM27, 0x00
	LONG $0x40a51362; WORD $0xdb43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM27, ZMM27, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x408d1362; WORD $0xd643; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM30, ZMM30, 0x00
	LONG $0x408d1362; WORD $0xde43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM30, ZMM30, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x48fed162; WORD $0x456f; BYTE $0x00 // VMOVDQU64 ZMM0, [r13]
	LONG $0x40fd3362; WORD $0xd043; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM16, ZMM16, 0x00
	LONG $0x40fd3362; WORD $0xd843; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM16, ZMM16, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40e53362; WORD $0xd343; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM19, ZMM19, 0x00
	LONG $0x40e53362; WORD $0xdb43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM19, ZMM19, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40cd3362; WORD $0xd643; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM22, ZMM22, 0x00
	LONG $0x40cd3362; WORD $0xde43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM22, ZMM22, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40b51362; WORD $0xd143; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM25, ZMM25, 0x00
	LONG $0x40b51362; WORD $0xd943; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM25, ZMM25, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x409d1362; WORD $0xd443; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM28, ZMM28, 0x00
	LONG $0x409d1362; WORD $0xdc43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM28, ZMM28, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x40851362; WORD $0xd743; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM31, ZMM31, 0x00
	LONG $0x40851362; WORD $0xdf43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM31, ZMM31, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x48fed162; WORD $0x066f // VMOVDQU64 ZMM0, [r14]
	LONG $0x40fd3362; WORD $0xd043; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM16, ZMM16, 0xaa
	LONG $0x40fd3362; WORD $0xd843; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM16, ZMM16, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40e53362; WORD $0xd343; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM19, ZMM19, 0xaa
	LONG $0x40e53362; WORD $0xdb43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM19, ZMM19, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40cd3362; WORD $0xd643; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM22, ZMM22, 0xaa
	LONG $0x40cd3362; WORD $0xde43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM22, ZMM22, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40b51362; WORD $0xd143; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM25, ZMM25, 0xaa
	LONG $0x40b51362; WORD $0xd943; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM25, ZMM25, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x409d1362; WORD $0xd443; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM28, ZMM28, 0x00
	LONG $0x409d1362; WORD $0xdc43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM28, ZMM28, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x40851362; WORD $0xd743; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM31, ZMM31, 0x00
	LONG $0x40851362; WORD $0xdf43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM31, ZMM31, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x48fef162; WORD $0x227f // VMOVDQU64 [rdx], ZMM4
	LONG $0x48fef162; WORD $0x297f // VMOVDQU64 [rcx], ZMM5
	LONG $0x48fed162; WORD $0x327f // VMOVDQU64 [r10], ZMM6
	LONG $0x48fed162; WORD $0x3c7f; BYTE $0x24 // VMOVDQU64 [r12], ZMM7
	LONG $0x48fe5162; WORD $0x077f // VMOVDQU64 [r15], ZMM8
	LONG $0x48fe5162; WORD $0x087f // VMOVDQU64 [r8], ZMM9

	ADDQ $64, SI  // in+=64
	ADDQ $64, AX  // in2+=64
	ADDQ $64, BX  // in3+=64
	ADDQ $64, DX  // out+=64
	ADDQ $64, CX  // out2+=64
	ADDQ $64, R10 // out3+=64
	ADDQ $64, R11 // in4+=64
	ADDQ $64, R12 // out4+=64
	ADDQ $64, R13 // in5+=64
	ADDQ $64, R14 // in6+=64
	ADDQ $64, R15 // in7+=64
	ADDQ $64, R8 // in8+=64

	SUBQ $1, R9
	JNZ  loopback_avx512_parallel66

done_avx512_parallel66:
	VZEROUPPER
	RET

TEXT ·galMulAVX512Parallel57(SB), 7, $0
	MOVQ  in+0(FP), SI     //
	MOVQ  8(SI), R9        // R9: len(in)
	SHRQ  $6, R9           // len(in) / 64
	TESTQ R9, R9
	JZ    done_avx512_parallel57

	MOVQ matrix+48(FP), SI
	LONG $0x48fe7162; WORD $0x366f // VMOVDQU64 ZMM14, 0x000[rsi]
	LONG $0x48fe7162; WORD $0x7e6f; BYTE $0x01 // VMOVDQU64 ZMM15, 0x040[rsi]
	LONG $0x48fee162; WORD $0x466f; BYTE $0x02 // VMOVDQU64 ZMM16, 0x080[rsi]
	LONG $0x48fee162; WORD $0x4e6f; BYTE $0x03 // VMOVDQU64 ZMM17, 0x0c0[rsi]
	LONG $0x48fee162; WORD $0x566f; BYTE $0x04 // VMOVDQU64 ZMM18, 0x100[rsi]
	LONG $0x48fee162; WORD $0x5e6f; BYTE $0x05 // VMOVDQU64 ZMM19, 0x140[rsi]
	LONG $0x48fee162; WORD $0x666f; BYTE $0x06 // VMOVDQU64 ZMM20, 0x180[rsi]
	LONG $0x48fee162; WORD $0x6e6f; BYTE $0x07 // VMOVDQU64 ZMM21, 0x1c0[rsi]
	LONG $0x48fee162; WORD $0x766f; BYTE $0x08 // VMOVDQU64 ZMM22, 0x200[rsi]
	LONG $0x48fee162; WORD $0x7e6f; BYTE $0x09 // VMOVDQU64 ZMM23, 0x240[rsi]
	LONG $0x48fe6162; WORD $0x466f; BYTE $0x0a // VMOVDQU64 ZMM24, 0x280[rsi]
	LONG $0x48fe6162; WORD $0x4e6f; BYTE $0x0b // VMOVDQU64 ZMM25, 0x2c0[rsi]
	LONG $0x48fe6162; WORD $0x566f; BYTE $0x0c // VMOVDQU64 ZMM26, 0x300[rsi]
	LONG $0x48fe6162; WORD $0x5e6f; BYTE $0x0d // VMOVDQU64 ZMM27, 0x340[rsi]
	LONG $0x48fe6162; WORD $0x666f; BYTE $0x0e // VMOVDQU64 ZMM28, 0x380[rsi]
	LONG $0x48fe6162; WORD $0x6e6f; BYTE $0x0f // VMOVDQU64 ZMM29, 0x3c0[rsi]
	LONG $0x48fe6162; WORD $0x766f; BYTE $0x10 // VMOVDQU64 ZMM30, 0x400[rsi]
	LONG $0x48fe6162; WORD $0x7e6f; BYTE $0x11 // VMOVDQU64 ZMM31, 0x440[rsi]

	MOVQ         $15, BX
	MOVQ         BX, X5
	LONG $0x487df262; WORD $0xd578 // VPBROADCASTB ZMM2, XMM5

	MOVB xor+72(FP), AX
	LONG $0xffc0c749; WORD $0xffff; BYTE $0xff // mov r8, -1
	WORD $0xf749; BYTE $0xe0 // mul r8
	LONG $0x92fbe1c4; BYTE $0xc8 // kmovq k1, rax
	MOVQ in+0(FP), SI  //  SI: &in
	MOVQ 24(SI), AX    //  AX: &in[1][0]
	MOVQ 48(SI), BX    //  BX: &in[2][0]
	MOVQ 72(SI), R11   // R11: &in[3][0]
	MOVQ 96(SI), R13   // R13: &in[4][0]
	MOVQ (SI), SI      //  SI: &in[0][0]
	MOVQ out+24(FP), DX
	MOVQ 24(DX), CX    //  CX: &out[1][0]
	MOVQ 48(DX), R10   // R10: &out[2][0]
	MOVQ 72(DX), R12   // R12: &out[3][0]
	MOVQ 96(DX), R15   // R15: &out[4][0]
	MOVQ 120(DX), R8   //  R8: &out[5][0]
	MOVQ 144(DX), R14  // R14: &out[6][0]
	MOVQ (DX), DX      //  DX: &out[0][0]

loopback_avx512_parallel57:
	LONG $0xc9fef162; WORD $0x226f // VMOVDQU64 ZMM4{k1}{z}, [rdx]
	LONG $0xc9fef162; WORD $0x296f // VMOVDQU64 ZMM5{k1}{z}, [rcx]
	LONG $0xc9fed162; WORD $0x326f // VMOVDQU64 ZMM6{k1}{z}, [r10]
	LONG $0xc9fed162; WORD $0x3c6f; BYTE $0x24 // VMOVDQU64 ZMM7{k1}{z}, [r12]
	LONG $0xc9fe5162; WORD $0x076f // VMOVDQU64 ZMM8{k1}{z}, [r15]
	LONG $0xc9fe5162; WORD $0x086f // VMOVDQU64 ZMM9{k1}{z}, [r8]
	LONG $0xc9fe5162; WORD $0x266f // VMOVDQU64 ZMM12{k1}{z}, [r14]

	LONG $0x48fef162; WORD $0x066f // VMOVDQU64 ZMM0, [rsi]
	LONG $0x488d5362; WORD $0xd643; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM14, ZMM14, 0x00
	LONG $0x488d5362; WORD $0xde43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM14, ZMM14, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40fd3362; WORD $0xd043; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM16, ZMM16, 0xaa
	LONG $0x40fd3362; WORD $0xd843; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM16, ZMM16, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40e53362; WORD $0xd343; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM19, ZMM19, 0x00
	LONG $0x40e53362; WORD $0xdb43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM19, ZMM19, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40d53362; WORD $0xd543; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM21, ZMM21, 0xaa
	LONG $0x40d53362; WORD $0xdd43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM21, ZMM21, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40bd1362; WORD $0xd043; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM24, ZMM24, 0x00
	LONG $0x40bd1362; WORD $0xd843; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM24, ZMM24, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x40ad1362; WORD $0xd243; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM26, ZMM26, 0xaa
	LONG $0x40ad1362; WORD $0xda43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM26, ZMM26, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x40951362; WORD $0xd543; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM29, ZMM29, 0x00
	LONG $0x40951362; WORD $0xdd43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM29, ZMM29, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x489d5162; WORD $0xe2ef // VPXORQ   ZMM12, ZMM12, ZMM10

	LONG $0x48fef162; WORD $0x006f // VMOVDQU64 ZMM0, [rax]
	LONG $0x488d5362; WORD $0xd643; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM14, ZMM14, 0xaa
	LONG $0x488d5362; WORD $0xde43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM14, ZMM14, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40f53362; WORD $0xd143; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM17, ZMM17, 0x00
	LONG $0x40f53362; WORD $0xd943; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM17, ZMM17, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40e53362; WORD $0xd343; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM19, ZMM19, 0xaa
	LONG $0x40e53362; WORD $0xdb43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM19, ZMM19, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40cd3362; WORD $0xd643; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM22, ZMM22, 0x00
	LONG $0x40cd3362; WORD $0xde43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM22, ZMM22, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40bd1362; WORD $0xd043; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM24, ZMM24, 0xaa
	LONG $0x40bd1362; WORD $0xd843; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM24, ZMM24, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x40a51362; WORD $0xd343; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM27, ZMM27, 0x00
	LONG $0x40a51362; WORD $0xdb43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM27, ZMM27, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x40951362; WORD $0xd543; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM29, ZMM29, 0xaa
	LONG $0x40951362; WORD $0xdd43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM29, ZMM29, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x489d5162; WORD $0xe2ef // VPXORQ   ZMM12, ZMM12, ZMM10

	LONG $0x48fef162; WORD $0x036f // VMOVDQU64 ZMM0, [rbx]
	LONG $0x48855362; WORD $0xd743; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM15, ZMM15, 0x00
	LONG $0x48855362; WORD $0xdf43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM15, ZMM15, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40f53362; WORD $0xd143; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM17, ZMM17, 0xaa
	LONG $0x40f53362; WORD $0xd943; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM17, ZMM17, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40dd3362; WORD $0xd443; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM20, ZMM20, 0x00
	LONG $0x40dd3362; WORD $0xdc43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM20, ZMM20, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40cd3362; WORD $0xd643; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM22, ZMM22, 0xaa
	LONG $0x40cd3362; WORD $0xde43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM22, ZMM22, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40b51362; WORD $0xd143; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM25, ZMM25, 0x00
	LONG $0x40b51362; WORD $0xd943; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM25, ZMM25, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x40a51362; WORD $0xd343; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM27, ZMM27, 0xaa
	LONG $0x40a51362; WORD $0xdb43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM27, ZMM27, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x408d1362; WORD $0xd643; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM30, ZMM30, 0x00
	LONG $0x408d1362; WORD $0xde43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM30, ZMM30, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x489d5162; WORD $0xe2ef // VPXORQ   ZMM12, ZMM12, ZMM10

	LONG $0x48fed162; WORD $0x036f // VMOVDQU64 ZMM0, [r11]
	LONG $0x48855362; WORD $0xd743; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM15, ZMM15, 0xaa
	LONG $0x48855362; WORD $0xdf43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM15, ZMM15, 0xff
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40ed3362; WORD $0xd243; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM18, ZMM18, 0x00
	LONG $0x40ed3362; WORD $0xda43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM18, ZMM18, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40dd3362; WORD $0xd443; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM20, ZMM20, 0xaa
	LONG $0x40dd3362; WORD $0xdc43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM20, ZMM20, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40c53362; WORD $0xd743; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM23, ZMM23, 0x00
	LONG $0x40c53362; WORD $0xdf43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM23, ZMM23, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40b51362; WORD $0xd143; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM25, ZMM25, 0xaa
	LONG $0x40b51362; WORD $0xd943; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM25, ZMM25, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x409d1362; WORD $0xd443; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM28, ZMM28, 0x00
	LONG $0x409d1362; WORD $0xdc43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM28, ZMM28, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x408d1362; WORD $0xd643; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM30, ZMM30, 0xaa
	LONG $0x408d1362; WORD $0xde43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM30, ZMM30, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x489d5162; WORD $0xe2ef // VPXORQ   ZMM12, ZMM12, ZMM10

	LONG $0x48fed162; WORD $0x456f; BYTE $0x00 // VMOVDQU64 ZMM0, [r13]
	LONG $0x40fd3362; WORD $0xd043; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM16, ZMM16, 0x00
	LONG $0x40fd3362; WORD $0xd843; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM16, ZMM16, 0x55
	LONG $0x48f5f162; WORD $0xd073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; high input
	LONG $0x48fdf162; WORD $0xc2db // VPANDQ   ZMM0, ZMM0, ZMM2  ; low input
	LONG $0x48f5f162; WORD $0xcadb // VPANDQ   ZMM1, ZMM1, ZMM2  ; high input
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48ddd162; WORD $0xe2ef // VPXORQ   ZMM4, ZMM4, ZMM10

	LONG $0x40ed3362; WORD $0xd243; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM18, ZMM18, 0xaa
	LONG $0x40ed3362; WORD $0xda43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM18, ZMM18, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48d5d162; WORD $0xeaef // VPXORQ   ZMM5, ZMM5, ZMM10

	LONG $0x40d53362; WORD $0xd543; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM21, ZMM21, 0x00
	LONG $0x40d53362; WORD $0xdd43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM21, ZMM21, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48cdd162; WORD $0xf2ef // VPXORQ   ZMM6, ZMM6, ZMM10

	LONG $0x40c53362; WORD $0xd743; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM23, ZMM23, 0xaa
	LONG $0x40c53362; WORD $0xdf43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM23, ZMM23, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48c5d162; WORD $0xfaef // VPXORQ   ZMM7, ZMM7, ZMM10

	LONG $0x40ad1362; WORD $0xd243; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM26, ZMM26, 0x00
	LONG $0x40ad1362; WORD $0xda43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM26, ZMM26, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48bd5162; WORD $0xc2ef // VPXORQ   ZMM8, ZMM8, ZMM10

	LONG $0x409d1362; WORD $0xd443; BYTE $0xaa // VSHUFI64x2 ZMM10, ZMM28, ZMM28, 0xaa
	LONG $0x409d1362; WORD $0xdc43; BYTE $0xff // VSHUFI64x2 ZMM11, ZMM28, ZMM28, 0xff
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x48b55162; WORD $0xcaef // VPXORQ   ZMM9, ZMM9, ZMM10

	LONG $0x40851362; WORD $0xd743; BYTE $0x00 // VSHUFI64x2 ZMM10, ZMM31, ZMM31, 0x00
	LONG $0x40851362; WORD $0xdf43; BYTE $0x55 // VSHUFI64x2 ZMM11, ZMM31, ZMM31, 0x55
	LONG $0x482d7262; WORD $0xd000 // VPSHUFB  ZMM10, ZMM10, ZMM0  ; mul low part
	LONG $0x48257262; WORD $0xd900 // VPSHUFB  ZMM11, ZMM11, ZMM1  ; mul high part
	LONG $0x48ad5162; WORD $0xd3ef // VPXORQ   ZMM10, ZMM10, ZMM11  ; result
	LONG $0x489d5162; WORD $0xe2ef // VPXORQ   ZMM12, ZMM12, ZMM10

	LONG $0x48fef162; WORD $0x227f // VMOVDQU64 [rdx], ZMM4
	LONG $0x48fef162; WORD $0x297f // VMOVDQU64 [rcx], ZMM5
	LONG $0x48fed162; WORD $0x327f // VMOVDQU64 [r10], ZMM6
	LONG $0x48fed162; WORD $0x3c7f; BYTE $0x24 // VMOVDQU64 [r12], ZMM7
	LONG $0x48fe5162; WORD $0x077f // VMOVDQU64 [r15], ZMM8
	LONG $0x48fe5162; WORD $0x087f // VMOVDQU64 [r8], ZMM9
	LONG $0x48fe5162; WORD $0x267f // VMOVDQU64 [r14], ZMM12

	ADDQ $64, SI  // in+=64
	ADDQ $64, AX  // in2+=64
	ADDQ $64, BX  // in3+=64
	ADDQ $64, DX  // out+=64
	ADDQ $64, CX  // out2+=64
	ADDQ $64, R10 // out3+=64
	ADDQ $64, R11 // in4+=64
	ADDQ $64, R12 // out4+=64
	ADDQ $64, R13 // in5+=64
	ADDQ $64, R14 // in6+=64
	ADDQ $64, R15 // in7+=64
	ADDQ $64, R8 // in8+=64

	SUBQ $1, R9
	JNZ  loopback_avx512_parallel57

done_avx512_parallel57:
	VZEROUPPER
	RET
