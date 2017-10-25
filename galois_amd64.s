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

// func galMulAVX2Xor(low, high, in, out []byte)
TEXT ·galMulAVX2Xor(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), X6          // X6 low
	MOVOU (DX), X7          // X7: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	LONG $0x384de3c4; WORD $0x01f6 // VINSERTI128 YMM6, YMM6, XMM6, 1 ; low
	LONG $0x3845e3c4; WORD $0x01ff // VINSERTI128 YMM7, YMM7, XMM7, 1 ; high
	LONG $0x787d62c4; BYTE $0xc5   // VPBROADCASTB YMM8, XMM5         ; Y8: lomask (unpacked)

	SHRQ  $5, R9         // len(in) /32
	MOVQ  out+72(FP), DX // DX: &out
	MOVQ  in+48(FP), SI  // R11: &in
	TESTQ R9, R9
	JZ    done_xor_avx2

loopback_xor_avx2:
	LONG $0x066ffec5             // VMOVDQU YMM0, [rsi]
	LONG $0x226ffec5             // VMOVDQU YMM4, [rdx]
	LONG $0xd073f5c5; BYTE $0x04 // VPSRLQ  YMM1, YMM0, 4       ; Y1: high input
	LONG $0xdb7dc1c4; BYTE $0xc0 // VPAND   YMM0, YMM0, YMM8    ; Y0: low input
	LONG $0xdb75c1c4; BYTE $0xc8 // VPAND   YMM1, YMM1, YMM8    ; Y1: high input
	LONG $0x004de2c4; BYTE $0xd0 // VPSHUFB  YMM2, YMM6, YMM0   ; Y2: mul low part
	LONG $0x0045e2c4; BYTE $0xd9 // VPSHUFB  YMM3, YMM7, YMM1   ; Y3: mul high part
	LONG $0xdbefedc5             // VPXOR   YMM3, YMM2, YMM3    ; Y3: Result
	LONG $0xe4efe5c5             // VPXOR   YMM4, YMM3, YMM4    ; Y4: Result
	LONG $0x227ffec5             // VMOVDQU [rdx], YMM4

	ADDQ $32, SI           // in+=32
	ADDQ $32, DX           // out+=32
	SUBQ $1, R9
	JNZ  loopback_xor_avx2

done_xor_avx2:
	// VZEROUPPER
	BYTE $0xc5; BYTE $0xf8; BYTE $0x77
	RET

// func galMulAVX2(low, high, in, out []byte)
TEXT ·galMulAVX2(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), X6          // X6 low
	MOVOU (DX), X7          // X7: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	LONG $0x384de3c4; WORD $0x01f6 // VINSERTI128 YMM6, YMM6, XMM6, 1 ; low
	LONG $0x3845e3c4; WORD $0x01ff // VINSERTI128 YMM7, YMM7, XMM7, 1 ; high
	LONG $0x787d62c4; BYTE $0xc5   // VPBROADCASTB YMM8, XMM5         ; Y8: lomask (unpacked)

	SHRQ  $5, R9         // len(in) /32
	MOVQ  out+72(FP), DX // DX: &out
	MOVQ  in+48(FP), SI  // R11: &in
	TESTQ R9, R9
	JZ    done_avx2

loopback_avx2:
	LONG $0x066ffec5             // VMOVDQU YMM0, [rsi]
	LONG $0xd073f5c5; BYTE $0x04 // VPSRLQ  YMM1, YMM0, 4       ; Y1: high input
	LONG $0xdb7dc1c4; BYTE $0xc0 // VPAND   YMM0, YMM0, YMM8    ; Y0: low input
	LONG $0xdb75c1c4; BYTE $0xc8 // VPAND   YMM1, YMM1, YMM8    ; Y1: high input
	LONG $0x004de2c4; BYTE $0xd0 // VPSHUFB  YMM2, YMM6, YMM0   ; Y2: mul low part
	LONG $0x0045e2c4; BYTE $0xd9 // VPSHUFB  YMM3, YMM7, YMM1   ; Y3: mul high part
	LONG $0xe3efedc5             // VPXOR   YMM4, YMM2, YMM3    ; Y4: Result
	LONG $0x227ffec5             // VMOVDQU [rdx], YMM4

	ADDQ $32, SI       // in+=32
	ADDQ $32, DX       // out+=32
	SUBQ $1, R9
	JNZ  loopback_avx2

done_avx2:

	BYTE $0xc5; BYTE $0xf8; BYTE $0x77 // VZEROUPPER
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

// func galMulAVX512Xor(low, high, in, out []byte)
TEXT ·galMulAVX512Xor(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low
	MOVQ  high+24(FP), DX   // DX: &high
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), X6          // X6 low
	MOVOU (DX), X7          // X7: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	LONG $0x384de3c4; WORD $0x01f6             // VINSERTI128 YMM6, YMM6, XMM6, 1  ; low
	LONG $0x3845e3c4; WORD $0x01ff             // VINSERTI128 YMM7, YMM7, XMM7, 1  ; high
	LONG $0x48CDF362; WORD $0xF63A; BYTE $0x01 // VINSERTI64x4 ZMM6, ZMM6, YMM6, 1 ; low
	LONG $0x48C5F362; WORD $0xFF3A; BYTE $0x01 // VINSERTI64x4 ZMM7, ZMM7, YMM7, 1 ; high
	LONG $0x487D7262; WORD $0xC578             // VPBROADCASTB zmm8, xmm5          ; X8: lomask (unpacked)

	SHRQ  $6, R9         // len(in) /64
	MOVQ  out+72(FP), DX // DX: &out
	MOVQ  in+48(FP), SI  // R11: &in
	TESTQ R9, R9
	JZ    done_xor_avx512

loopback_xor_avx512:
	LONG $0x48FEF162; WORD $0x066F             // VMOVDQU64 ZMM0, [rsi]
	LONG $0x48FEF162; WORD $0x226F             // VMOVDQU64 ZMM4, [rdx]
	LONG $0x48F5F162; WORD $0xD073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; Z1: high input
	LONG $0x48FDD162; WORD $0xC0DB             // VPANDQ   ZMM0, ZMM0, ZMM8  ; Z0: low input
	LONG $0x48F5D162; WORD $0xC8DB             // VPANDQ   ZMM1, ZMM1, ZMM8  ; Z1: high input
	LONG $0x484DF262; WORD $0xD000             // VPSHUFB  ZMM2, ZMM6, ZMM0  ; Z2: mul low part
	LONG $0x4845F262; WORD $0xD900             // VPSHUFB  ZMM3, ZMM7, ZMM1  ; Z3: mul high part
	LONG $0x48EDF162; WORD $0xDBEF             // VPXORQ   ZMM3, ZMM2, ZMM3  ; Z3: Result
	LONG $0x48E5F162; WORD $0xE4EF             // VPXORQ   ZMM4, ZMM3, ZMM4  ; Z4: Result
	LONG $0x48FEF162; WORD $0x227F             // VMOVDQU64 [rdx], ZMM4

	ADDQ $64, SI       // in+=64
	ADDQ $64, DX       // out+=64
	SUBQ $1, R9
	JNZ  loopback_xor_avx512

done_xor_avx512:
	// VZEROUPPER
	BYTE $0xc5; BYTE $0xf8; BYTE $0x77
	RET

// func galMulAVX512(low, high, in, out []byte)
TEXT ·galMulAVX512(SB), 7, $0
	MOVQ  low+0(FP), SI     // SI: &low table
	MOVQ  high+24(FP), DX   // DX: &high table
	MOVQ  $15, BX           // BX: low mask
	MOVQ  BX, X5
	MOVOU (SI), X6          // X6 low
	MOVOU (DX), X7          // X7: high
	MOVQ  in_len+56(FP), R9 // R9: len(in)

	LONG $0x384de3c4; WORD $0x01f6             // VINSERTI128 YMM6, YMM6, XMM6, 1  ; low
	LONG $0x3845e3c4; WORD $0x01ff             // VINSERTI128 YMM7, YMM7, XMM7, 1  ; high
	LONG $0x48CDF362; WORD $0xF63A; BYTE $0x01 // VINSERTI64x4 ZMM6, ZMM6, YMM6, 1 ; low
	LONG $0x48C5F362; WORD $0xFF3A; BYTE $0x01 // VINSERTI64x4 ZMM7, ZMM7, YMM7, 1 ; high
	LONG $0x487D7262; WORD $0xC578             // VPBROADCASTB zmm8, xmm5          ; X8: lomask (unpacked)

	SHRQ  $6, R9         // len(in) /64
	MOVQ  out+72(FP), DX // DX: &out
	MOVQ  in+48(FP), SI  // R11: &in
	TESTQ R9, R9
	JZ    done_avx512

loopback_avx512:
	LONG $0x48FEF162; WORD $0x066F             // VMOVDQU64 ZMM0, [rsi]
	LONG $0x48F5F162; WORD $0xD073; BYTE $0x04 // VPSRLQ   ZMM1, ZMM0, 4     ; Z1: high input
	LONG $0x48FDD162; WORD $0xC0DB             // VPANDQ   ZMM0, ZMM0, ZMM8  ; Z0: low input
	LONG $0x48F5D162; WORD $0xC8DB             // VPANDQ   ZMM1, ZMM1, ZMM8  ; Z1: high input
	LONG $0x484DF262; WORD $0xD000             // VPSHUFB  ZMM2, ZMM6, ZMM0  ; Z2: mul low part
	LONG $0x4845F262; WORD $0xD900             // VPSHUFB  ZMM3, ZMM7, ZMM1  ; Z3: mul high part
	LONG $0x48EDF162; WORD $0xE3EF             // VPXORQ   ZMM4, ZMM2, ZMM3  ; Z4: Result
	LONG $0x48FEF162; WORD $0x227F             // VMOVDQU64 [rdx], ZMM4

	ADDQ $64, SI       // in+=64
	ADDQ $64, DX       // out+=64
	SUBQ $1, R9
	JNZ  loopback_avx512

done_avx512:
	BYTE $0xc5; BYTE $0xf8; BYTE $0x77 // VZEROUPPER
	RET
