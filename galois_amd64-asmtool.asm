
#define MULMASK(z) \
	MOVQ         $15, BX \
	MOVQ         BX, X5  \
	vpbroadcastb z, xmm5

#define mask zmm2
#define inhi zmm1

#define GFMULL(in, lo, hi) \
	vpshufb  lo, lo, in \
	vpshufb  hi, hi, inhi \
	vpxorq   lo, lo, hi 

#define GFMULLXOR1(lo, hi, out, in) \
	vpsrlq   inhi, in, 4 \
	vpandq   in, in, mask \
	vpandq   inhi, inhi, mask \
	GFMULL(in, lo, hi) \
	vpxorq out, out, lo

#define GFMULLXOR2(lo, hi, out, in) \
        GFMULL(in, lo, hi) \
        vpxorq out, out, lo

// Setup multiplication consts out of Least Significant Half
#define MULCONSTLS(lo, hi, src) \
	vshufi64x2 lo, src, src, 0x00 \
	vshufi64x2 hi, src, src, 0x55

// Setup multiplication consts out of Most Significant Half
#define MULCONSTMS(lo, hi, src) \
	vshufi64x2 lo, src, src, 0xaa \
	vshufi64x2 hi, src, src, 0xff

TEXT ·galMulAVX512Parallel66(SB), 7, $0
	MOVQ  in+0(FP), SI
	MOVQ  8(SI), R9              // R9: len(in)
	SHRQ  $6, R9                 // len(in) / 64
	TESTQ R9, R9
	JZ    done_avx512_parallel66

	// Load multiplication constants into registers
	MOVQ      matrix+48(FP), SI
	vmovdqu64 zmm14, 0x000[rsi]
	vmovdqu64 zmm15, 0x040[rsi]
	vmovdqu64 zmm16, 0x080[rsi]
	vmovdqu64 zmm17, 0x0c0[rsi]
	vmovdqu64 zmm18, 0x100[rsi]
	vmovdqu64 zmm19, 0x140[rsi]
	vmovdqu64 zmm20, 0x180[rsi]
	vmovdqu64 zmm21, 0x1c0[rsi]
	vmovdqu64 zmm22, 0x200[rsi]
	vmovdqu64 zmm23, 0x240[rsi]
	vmovdqu64 zmm24, 0x280[rsi]
	vmovdqu64 zmm25, 0x2c0[rsi]
	vmovdqu64 zmm26, 0x300[rsi]
	vmovdqu64 zmm27, 0x340[rsi]
	vmovdqu64 zmm28, 0x380[rsi]
	vmovdqu64 zmm29, 0x3c0[rsi]
	vmovdqu64 zmm30, 0x400[rsi]
	vmovdqu64 zmm31, 0x440[rsi]

	MULMASK(mask)

	// Set k1 mask to either load or clear existing output
	MOVB  xor+72(FP), AX
	mov   r8, -1
	mul   r8
	kmovq k1, rax

	// Load pointers for input
	MOVQ in+0(FP), SI // SI: &in
	MOVQ 24(SI), AX   // AX: &in[1][0]
	MOVQ 48(SI), BX   // BX: &in[2][0]
	MOVQ 72(SI), R11  // R11: &in[3][0]
	MOVQ 96(SI), R13  // R13: &in[4][0]
	MOVQ 120(SI), R14 // R14: &in[5][0]
	MOVQ (SI), SI     // SI: &in[0][0]

	// Load pointers for output
	MOVQ out+24(FP), DX
	MOVQ 24(DX), CX     // CX: &out[1][0]
	MOVQ 48(DX), R10    // R10: &out[2][0]
	MOVQ 72(DX), R12    // R12: &out[3][0]
	MOVQ 96(DX), R15    // R15: &out[4][0]
	MOVQ 120(DX), R8    // R8: &out[5][0]
	MOVQ (DX), DX       // DX: &out[0][0]

	// Main loop
loopback_avx512_parallel66:
	vmovdqu64 zmm4{k1}{z}, [rdx]
	vmovdqu64 zmm5{k1}{z}, [rcx]
	vmovdqu64 zmm6{k1}{z}, [r10]
	vmovdqu64 zmm7{k1}{z}, [r12]
	vmovdqu64 zmm8{k1}{z}, [r15]
	vmovdqu64 zmm9{k1}{z}, [r8]

	vmovdqu64 zmm0, [rsi]
	MULCONSTLS(zmm10, zmm11, zmm14)
	GFMULLXOR1(zmm10, zmm11, zmm4, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm17)
	GFMULLXOR2(zmm10, zmm11, zmm5, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm20)
	GFMULLXOR2(zmm10, zmm11, zmm6, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm23)
	GFMULLXOR2(zmm10, zmm11, zmm7, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm26)
	GFMULLXOR2(zmm10, zmm11, zmm8, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm29)
	GFMULLXOR2(zmm10, zmm11, zmm9, zmm0)

	vmovdqu64 zmm0, [rax]
	MULCONSTMS(zmm10, zmm11, zmm14)
	GFMULLXOR1(zmm10, zmm11, zmm4, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm17)
	GFMULLXOR2(zmm10, zmm11, zmm5, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm20)
	GFMULLXOR2(zmm10, zmm11, zmm6, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm23)
	GFMULLXOR2(zmm10, zmm11, zmm7, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm26)
	GFMULLXOR2(zmm10, zmm11, zmm8, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm29)
	GFMULLXOR2(zmm10, zmm11, zmm9, zmm0)

	vmovdqu64 zmm0, [rbx]
	MULCONSTLS(zmm10, zmm11, zmm15)
	GFMULLXOR1(zmm10, zmm11, zmm4, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm18)
	GFMULLXOR2(zmm10, zmm11, zmm5, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm21)
	GFMULLXOR2(zmm10, zmm11, zmm6, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm24)
	GFMULLXOR2(zmm10, zmm11, zmm7, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm27)
	GFMULLXOR2(zmm10, zmm11, zmm8, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm30)
	GFMULLXOR2(zmm10, zmm11, zmm9, zmm0)

	vmovdqu64 zmm0, [r11]
	MULCONSTMS(zmm10, zmm11, zmm15)
	GFMULLXOR1(zmm10, zmm11, zmm4, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm18)
	GFMULLXOR2(zmm10, zmm11, zmm5, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm21)
	GFMULLXOR2(zmm10, zmm11, zmm6, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm24)
	GFMULLXOR2(zmm10, zmm11, zmm7, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm27)
	GFMULLXOR2(zmm10, zmm11, zmm8, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm30)
	GFMULLXOR2(zmm10, zmm11, zmm9, zmm0)

	vmovdqu64 zmm0, [r13]
	MULCONSTLS(zmm10, zmm11, zmm16)
	GFMULLXOR1(zmm10, zmm11, zmm4, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm19)
	GFMULLXOR2(zmm10, zmm11, zmm5, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm22)
	GFMULLXOR2(zmm10, zmm11, zmm6, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm25)
	GFMULLXOR2(zmm10, zmm11, zmm7, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm28)
	GFMULLXOR2(zmm10, zmm11, zmm8, zmm0)
	MULCONSTLS(zmm10, zmm11, zmm31)
	GFMULLXOR2(zmm10, zmm11, zmm9, zmm0)

	vmovdqu64 zmm0, [r14]
	MULCONSTMS(zmm10, zmm11, zmm16)
	GFMULLXOR1(zmm10, zmm11, zmm4, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm19)
	GFMULLXOR2(zmm10, zmm11, zmm5, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm22)
	GFMULLXOR2(zmm10, zmm11, zmm6, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm25)
	GFMULLXOR2(zmm10, zmm11, zmm7, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm28)
	GFMULLXOR2(zmm10, zmm11, zmm8, zmm0)
	MULCONSTMS(zmm10, zmm11, zmm31)
	GFMULLXOR2(zmm10, zmm11, zmm9, zmm0)
	vmovdqu64 [rdx], zmm4
	vmovdqu64 [rcx], zmm5
	vmovdqu64 [r10], zmm6
	vmovdqu64 [r12], zmm7
	vmovdqu64 [r15], zmm8
	vmovdqu64 [r8], zmm9

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
	ADDQ $64, R8  // in8+=64

	SUBQ $1, R9
	JNZ  loopback_avx512_parallel66

done_avx512_parallel66:
	VZEROUPPER

	RET
