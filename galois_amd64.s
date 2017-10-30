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

#define TMP0 Y10
#define TMP1 Y11

#define MASK Y13
#define LO Y14
#define HI Y15
#define XLO X14
#define XHI X15

#define GFMULL(ymm, lo, hi, res) \
	VPSRLQ  $4, ymm, TMP1    \ // TMP1: high input
	VPAND   MASK, ymm, TMP0  \ // TMP0: low input
	VPAND   MASK, TMP1, TMP1 \ // TMP1: high input
	VPSHUFB TMP0, lo, TMP0   \ // Y2: mul low part
	VPSHUFB TMP1, hi, TMP1   \ // Y3: mul high part
	VPXOR   TMP0, TMP1, res  // Y3: Result

// func galMulAVX2Xor(low, high, in, out []byte)
TEXT ·galMulAVX2Xor(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), XLO         // XLO: low
	MOVOU (DX), XHI         // XHI: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	VINSERTI128  $1, XLO, LO, LO // low
	VINSERTI128  $1, XHI, HI, HI // high
	VPBROADCASTB X5, MASK        // lomask (unpacked)

	SHRQ  $5, R9         // len(in) / 32
	MOVQ  out+72(FP), DX // DX: &out
	MOVQ  in+48(FP), SI  // SI: &in
	TESTQ R9, R9
	JZ    done_xor_avx2

loopback_xor_avx2:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result
	VMOVDQU Y4, (DX)

	ADDQ $32, SI           // in+=32
	ADDQ $32, DX           // out+=32
	SUBQ $1, R9
	JNZ  loopback_xor_avx2

done_xor_avx2:
	VZEROUPPER
	RET

// func galMulAVX2(low, high, in, out []byte)
TEXT ·galMulAVX2(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), XLO         // XLO: low
	MOVOU (DX), XHI         // XHI: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	VINSERTI128  $1, XLO, LO, LO // low
	VINSERTI128  $1, XHI, HI, HI // high
	VPBROADCASTB X5, MASK        // lomask (unpacked)

	SHRQ  $5, R9         // len(in) / 32
	MOVQ  out+72(FP), DX // DX: &out
	MOVQ  in+48(FP), SI  // SI: &in
	TESTQ R9, R9
	JZ    done_avx2

loopback_avx2:
	VMOVDQU (SI), Y0
	GFMULL(Y0, LO, HI, Y3)
	VMOVDQU Y3, (DX)

	ADDQ $32, SI       // in+=32
	ADDQ $32, DX       // out+=32
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
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), XLO         // XLO: low
	MOVOU (DX), XHI         // XHI: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	VINSERTI128  $1, XLO, LO, LO // low
	VINSERTI128  $1, XHI, HI, HI // high
	VPBROADCASTB X5, MASK        // lomask (unpacked)

	SHRQ  $5, R9                  // len(in) / 32
	MOVQ  out+72(FP), DX          // DX: &out
	MOVQ  in+48(FP), SI           // SI: &in
	MOVQ  in2+96(FP), AX          // AX: &in2
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel2

loopback_xor_avx2_parallel2:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU (AX), Y0
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU Y4, (DX)

	ADDQ $32, SI                     // in+=32
	ADDQ $32, AX                     // in2=32
	ADDQ $32, DX                     // out+=32
	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel2

done_xor_avx2_parallel2:
	VZEROUPPER
	RET

// func galMulAVX2XorParallel3(low, high, in, out, in2, in3 []byte)
TEXT ·galMulAVX2XorParallel3(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), XLO         // XLO: low
	MOVOU (DX), XHI         // XHI: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	VINSERTI128  $1, XLO, LO, LO // low
	VINSERTI128  $1, XHI, HI, HI // high
	VPBROADCASTB X5, MASK        // lomask (unpacked)

	SHRQ  $5, R9                  // len(in) / 32
	MOVQ  out+72(FP), DX          // DX: &out
	MOVQ  in+48(FP), SI           // SI: &in
	MOVQ  in2+96(FP), AX          // AX: &in2
	MOVQ  in3+120(FP), BX         // BX: &in3
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel3

loopback_xor_avx2_parallel3:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU (AX), Y0
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU (BX), Y0
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU Y4, (DX)

	ADDQ $32, SI                     // in+=32
	ADDQ $32, AX                     // in2=32
	ADDQ $32, BX                     // in3=32
	ADDQ $32, DX                     // out+=32
	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel3

done_xor_avx2_parallel3:
	VZEROUPPER
	RET

// func galMulAVX2XorParallel4(low, high, in, out, in2, in3 []byte)
TEXT ·galMulAVX2XorParallel4(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), XLO         // XLO: low
	MOVOU (DX), XHI         // XHI: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	VINSERTI128  $1, XLO, LO, LO // low
	VINSERTI128  $1, XHI, HI, HI // high
	VPBROADCASTB X5, MASK        // lomask (unpacked)

	SHRQ  $5, R9                  // len(in) / 32
	MOVQ  out+72(FP), DX          // DX: &out
	MOVQ  in+48(FP), SI           // SI: &in
	MOVQ  in2+96(FP), AX          // AX: &in2
	MOVQ  in3+120(FP), BX         // BX: &in3
	MOVQ  in4+144(FP), CX         // CX: &in4
	TESTQ R9, R9
	JZ    done_xor_avx2_parallel4

loopback_xor_avx2_parallel4:
	VMOVDQU (SI), Y0
	VMOVDQU (DX), Y4
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU (AX), Y0
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU (BX), Y0
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU (CX), Y0
	GFMULL(Y0, LO, HI, Y3)
	VPXOR   Y4, Y3, Y4 // Y4: Result

	VMOVDQU Y4, (DX)

	ADDQ $32, SI                     // in+=32
	ADDQ $32, AX                     // in2=32
	ADDQ $32, BX                     // in3=32
	ADDQ $32, CX                     // in4=32
	ADDQ $32, DX                     // out+=32
	SUBQ $1, R9
	JNZ  loopback_xor_avx2_parallel4

done_xor_avx2_parallel4:
	VZEROUPPER
	RET
