//+build ignore

package main

import (
	"fmt"
	_ "strings"
)

func PLAN9LABEL(format string, a ...interface{}) {
	fmt.Printf(format + "\n", a...)
}

func PLAN9INSTR(format string, a ...interface{}) {
	if format != "" {
		fmt.Printf("	" + format + "\n", a...)
	} else {
		fmt.Println()
	}
}

func INTELINSTR(format string, a ...interface{}) {
	//fmt.Printf("	                 // " + format + "\n", a...)
	fmt.Printf("	" + format + "\n", a...)
}

func MULTABLE(loaddr, hiaddr string, lovec, hivec string) {

	fmt.Println()
	fmt.Printf("	MOVQ %s, SI\n", loaddr)
	fmt.Printf("	MOVQ %s, DX\n", hiaddr)
	fmt.Printf("	                 // VBROADCASTI64X2 %s, [rsi]\n", lovec)
	fmt.Printf("	                 // VBROADCASTI64X2 %s, [rdx]\n", hivec)
}

func MULMASK(vec string) {

	PLAN9INSTR("")
	PLAN9INSTR("MOVQ $15, BX")
	PLAN9INSTR("MOVQ BX, X5")
	INTELINSTR("vpbroadcastb %s, xmm5", vec)
}

func GFMULL(in, lo, hi string, setup bool) string {

	mask := lo[0:3] + "2"
	inhi := lo[0:3] + "1"

	if setup {
		INTELINSTR("vpsrlq %s, %s, 4", inhi, in)
		INTELINSTR("vpandq %s, %s, %s", in, in, mask)
		INTELINSTR("vpandq %s, %s, %s", inhi, inhi, mask)
	}
	INTELINSTR("vpshufb %s, %s, %s", lo, lo, in)
	INTELINSTR("vpshufb %s, %s, %s", hi, hi, inhi)
	INTELINSTR("vpxorq %s, %s, %s", lo, lo, hi)

	return lo
}


func GFMULLXOR1(lo, hi, out, in string) {
	m := GFMULL(in, lo, hi, true)
	INTELINSTR("vpxorq %s, %s, %s", out, out, m)
	//PLAN9INSTR("")
}

func GFMULLXOR2(lo, hi, out, in string) {
	m := GFMULL(in, lo, hi, false)
	INTELINSTR("vpxorq %s, %s, %s", out, out, m)
	//PLAN9INSTR("")
}

// Setup multiplication consts out of Least Significant Half
func MULCONSTLS(lo, hi, src string) {
	INTELINSTR("vshufi64x2 %s, %s, %s, 0x00", lo, src, src)
	INTELINSTR("vshufi64x2 %s, %s, %s, 0x55", hi, src, src)
}

// Setup multiplication consts out of Most Significant Half
func MULCONSTMS(lo, hi, src string) {
	INTELINSTR("vshufi64x2 %s, %s, %s, 0xaa", lo, src, src)
	INTELINSTR("vshufi64x2 %s, %s, %s, 0xff", hi, src, src)
}

func AVX512XorParallel84() {

	// Register usage
	// ZMM16 - ZMM31: multiplication table

	const config = "84"

	// func galMulAVX512Parallel84(in, out [][]byte, matrix []byte, clear bool)
	PLAN9LABEL("TEXT ·galMulAVX512Parallel%s(SB), 7, $0", config)
	PLAN9INSTR("MOVQ  in+0(FP), SI     // ")
	PLAN9INSTR("MOVQ  8(SI), R9        // R9: len(in)")
	PLAN9INSTR("SHRQ  $6, R9           // len(in) / 64")
	PLAN9INSTR("TESTQ R9, R9")
	PLAN9INSTR("JZ    done_avx512_parallel%s", config)
	PLAN9INSTR("")

	// Load multiplication constants into registers
	PLAN9INSTR("MOVQ matrix+48(FP), SI")
	INTELINSTR("VMOVDQU64 ZMM16, 0x000[rsi]")
	INTELINSTR("VMOVDQU64 ZMM17, 0x040[rsi]")
	INTELINSTR("VMOVDQU64 ZMM18, 0x080[rsi]")
	INTELINSTR("VMOVDQU64 ZMM19, 0x0c0[rsi]")
	INTELINSTR("VMOVDQU64 ZMM20, 0x100[rsi]")
	INTELINSTR("VMOVDQU64 ZMM21, 0x140[rsi]")
	INTELINSTR("VMOVDQU64 ZMM22, 0x180[rsi]")
	INTELINSTR("VMOVDQU64 ZMM23, 0x1c0[rsi]")
	INTELINSTR("VMOVDQU64 ZMM24, 0x200[rsi]")
	INTELINSTR("VMOVDQU64 ZMM25, 0x240[rsi]")
	INTELINSTR("VMOVDQU64 ZMM26, 0x280[rsi]")
	INTELINSTR("VMOVDQU64 ZMM27, 0x2c0[rsi]")
	INTELINSTR("VMOVDQU64 ZMM28, 0x300[rsi]")
	INTELINSTR("VMOVDQU64 ZMM29, 0x340[rsi]")
	INTELINSTR("VMOVDQU64 ZMM30, 0x380[rsi]")
	INTELINSTR("VMOVDQU64 ZMM31, 0x3c0[rsi]")

	MULMASK("ZMM2")
	PLAN9INSTR("")

	// Set k1 mask to either load or clear existing output
	PLAN9INSTR("MOVB xor+72(FP), AX")
	INTELINSTR("mov r8, -1")
	INTELINSTR("mul r8")
	INTELINSTR("kmovq k1, rax")

	// Load pointers for input
	PLAN9INSTR("MOVQ in+0(FP), SI  //  SI: &in")
	PLAN9INSTR("MOVQ 24(SI), AX    //  AX: &in[1][0]")
	PLAN9INSTR("MOVQ 48(SI), BX    //  BX: &in[2][0]")
	PLAN9INSTR("MOVQ 72(SI), R11   // R11: &in[3][0]")
	PLAN9INSTR("MOVQ 96(SI), R13   // R13: &in[4][0]")
	PLAN9INSTR("MOVQ 120(SI), R14  // R14: &in[5][0]")
	PLAN9INSTR("MOVQ 144(SI), R15  // R15: &in[6][0]")
	PLAN9INSTR("MOVQ 168(SI), R8   //  R8: &in[7][0]")
	PLAN9INSTR("MOVQ (SI), SI      //  SI: &in[0][0]")

	// Load pointers for output
	PLAN9INSTR("MOVQ out+24(FP), DX")
	PLAN9INSTR("MOVQ 24(DX), CX    //  CX: &out[1][0]")
	PLAN9INSTR("MOVQ 48(DX), R10   // R10: &out[2][0]")
	PLAN9INSTR("MOVQ 72(DX), R12   // R12: &out[3][0]")
	PLAN9INSTR("MOVQ (DX), DX      //  DX: &out[0][0]")
	PLAN9INSTR("")

	// Main loop
	PLAN9LABEL("loopback_avx512_parallel%s:", config)
	INTELINSTR("VMOVDQU64 %s, [rdx]", "ZMM4{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [rcx]", "ZMM5{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [r10]", "ZMM6{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [r12]", "ZMM7{k1}{z}")
	PLAN9INSTR("")

	INTELINSTR("VMOVDQU64 %s, [rsi]", "ZMM0")
	MULCONSTLS("ZMM14", "ZMM15", "ZMM16")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTLS("ZMM12", "ZMM13", "ZMM20")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM24")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTLS("ZMM8", "ZMM9", "ZMM28")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [rax]", "ZMM0")
	MULCONSTMS("ZMM14", "ZMM15", "ZMM16")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTMS("ZMM12", "ZMM13", "ZMM20")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM24")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTMS("ZMM8", "ZMM9", "ZMM28")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [rbx]", "ZMM0")
	MULCONSTLS("ZMM14", "ZMM15", "ZMM17")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTLS("ZMM12", "ZMM13", "ZMM21")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM25")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTLS("ZMM8", "ZMM9", "ZMM29")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [r11]", "ZMM0")
	MULCONSTMS("ZMM14", "ZMM15", "ZMM17")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTMS("ZMM12", "ZMM13", "ZMM21")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM25")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTMS("ZMM8", "ZMM9", "ZMM29")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [r13]", "ZMM0")
	MULCONSTLS("ZMM14", "ZMM15", "ZMM18")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTLS("ZMM12", "ZMM13", "ZMM22")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM26")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTLS("ZMM8", "ZMM9", "ZMM30")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [r14]", "ZMM0")
	MULCONSTMS("ZMM14", "ZMM15", "ZMM18")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTMS("ZMM12", "ZMM13", "ZMM22")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM26")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTMS("ZMM8", "ZMM9", "ZMM30")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [r15]", "ZMM0")
	MULCONSTLS("ZMM14", "ZMM15", "ZMM19")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTLS("ZMM12", "ZMM13", "ZMM23")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM27")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTLS("ZMM8", "ZMM9", "ZMM31")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [r8]", "ZMM0")
	MULCONSTMS("ZMM14", "ZMM15", "ZMM19")
	GFMULLXOR1("ZMM14", "ZMM15", "ZMM4", "ZMM0")
	MULCONSTMS("ZMM12", "ZMM13", "ZMM23")
	GFMULLXOR2("ZMM12", "ZMM13", "ZMM5", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM27")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTMS("ZMM8", "ZMM9", "ZMM31")
	GFMULLXOR2("ZMM8", "ZMM9", "ZMM7", "ZMM0")

	INTELINSTR("VMOVDQU64 [rdx], %s", "ZMM4")
	INTELINSTR("VMOVDQU64 [rcx], %s", "ZMM5")
	INTELINSTR("VMOVDQU64 [r10], %s", "ZMM6")
	INTELINSTR("VMOVDQU64 [r12], %s", "ZMM7")
	PLAN9INSTR("")
	PLAN9INSTR("ADDQ $64, SI  // in+=64")
	PLAN9INSTR("ADDQ $64, AX  // in2+=64")
	PLAN9INSTR("ADDQ $64, BX  // in3+=64")
	PLAN9INSTR("ADDQ $64, DX  // out+=64")
	PLAN9INSTR("ADDQ $64, CX  // out2+=64")
	PLAN9INSTR("ADDQ $64, R10 // out3+=64")
	PLAN9INSTR("ADDQ $64, R11 // in4+=64")
	PLAN9INSTR("ADDQ $64, R12 // out4+=64")
	PLAN9INSTR("ADDQ $64, R13 // in5+=64")
	PLAN9INSTR("ADDQ $64, R14 // in6+=64")
	PLAN9INSTR("ADDQ $64, R15 // in7+=64")
	PLAN9INSTR("ADDQ $64, R8 // in8+=64")
	PLAN9INSTR("")
	PLAN9INSTR("SUBQ $1, R9")
	PLAN9INSTR("JNZ  loopback_avx512_parallel%s", config)
	PLAN9INSTR("")
	PLAN9LABEL("done_avx512_parallel%s:", config)
	PLAN9INSTR("VZEROUPPER")
	PLAN9INSTR("RET")
}

func AVX512XorParallel66() {

	// Register usage
	// ZMM16 - ZMM31: multiplication table

	const config = "66"

	// func galMulAVX512Parallel66(in, out [][]byte, matrix []byte, clear bool)
	PLAN9LABEL("TEXT ·galMulAVX512Parallel%s(SB), 7, $0", config)
	PLAN9INSTR("MOVQ in+0(FP), SI")     // ")
	PLAN9INSTR("MOVQ 8(SI), R9")        // R9: len(in)")
	PLAN9INSTR("SHRQ $6, R9")           // len(in) / 64")
	PLAN9INSTR("TESTQ R9, R9")
	PLAN9INSTR("JZ done_avx512_parallel%s", config)
	PLAN9INSTR("")

	// Load multiplication constants into registers
	PLAN9INSTR("MOVQ matrix+48(FP), SI")
	INTELINSTR("vmovdqu64 zmm14, 0x000[rsi]")
	INTELINSTR("vmovdqu64 zmm15, 0x040[rsi]")
	INTELINSTR("vmovdqu64 zmm16, 0x080[rsi]")
	INTELINSTR("vmovdqu64 zmm17, 0x0c0[rsi]")
	INTELINSTR("vmovdqu64 zmm18, 0x100[rsi]")
	INTELINSTR("vmovdqu64 zmm19, 0x140[rsi]")
	INTELINSTR("vmovdqu64 zmm20, 0x180[rsi]")
	INTELINSTR("vmovdqu64 zmm21, 0x1c0[rsi]")
	INTELINSTR("vmovdqu64 zmm22, 0x200[rsi]")
	INTELINSTR("vmovdqu64 zmm23, 0x240[rsi]")
	INTELINSTR("vmovdqu64 zmm24, 0x280[rsi]")
	INTELINSTR("vmovdqu64 zmm25, 0x2c0[rsi]")
	INTELINSTR("vmovdqu64 zmm26, 0x300[rsi]")
	INTELINSTR("vmovdqu64 zmm27, 0x340[rsi]")
	INTELINSTR("vmovdqu64 zmm28, 0x380[rsi]")
	INTELINSTR("vmovdqu64 zmm29, 0x3c0[rsi]")
	INTELINSTR("vmovdqu64 zmm30, 0x400[rsi]")
	INTELINSTR("vmovdqu64 zmm31, 0x440[rsi]")

	MULMASK("zmm2")
	PLAN9INSTR("")

	// Set k1 mask to either load or clear existing output
	PLAN9INSTR("MOVB xor+72(FP), AX")
	INTELINSTR("mov r8, -1")
	INTELINSTR("mul r8")
	INTELINSTR("kmovq k1, rax")

	// Load pointers for input
	PLAN9INSTR("MOVQ in+0(FP), SI")   //  SI: &in")
	PLAN9INSTR("MOVQ 24(SI), AX")    //  AX: &in[1][0]")
	PLAN9INSTR("MOVQ 48(SI), BX")    //  BX: &in[2][0]")
	PLAN9INSTR("MOVQ 72(SI), R11")   // R11: &in[3][0]")
	PLAN9INSTR("MOVQ 96(SI), R13")   // R13: &in[4][0]")
	PLAN9INSTR("MOVQ 120(SI), R14")  // R14: &in[5][0]")
	PLAN9INSTR("MOVQ (SI), SI")      //  SI: &in[0][0]")

	// Load pointers for output
	PLAN9INSTR("MOVQ out+24(FP), DX")
	PLAN9INSTR("MOVQ 24(DX), CX")    //  CX: &out[1][0]")
	PLAN9INSTR("MOVQ 48(DX), R10")   // R10: &out[2][0]")
	PLAN9INSTR("MOVQ 72(DX), R12")   // R12: &out[3][0]")
	PLAN9INSTR("MOVQ 96(DX), R15")   // R15: &out[4][0]")
	PLAN9INSTR("MOVQ 120(DX), R8")   //  R8: &out[5][0]")
	PLAN9INSTR("MOVQ (DX), DX")      //  DX: &out[0][0]")
	PLAN9INSTR("")

	// Main loop
	PLAN9LABEL("loopback_avx512_parallel%s:", config)
	INTELINSTR("vmovdqu64 %s, [rdx]", "zmm4{k1}{z}")
	INTELINSTR("vmovdqu64 %s, [rcx]", "zmm5{k1}{z}")
	INTELINSTR("vmovdqu64 %s, [r10]", "zmm6{k1}{z}")
	INTELINSTR("vmovdqu64 %s, [r12]", "zmm7{k1}{z}")
	INTELINSTR("vmovdqu64 %s, [r15]", "zmm8{k1}{z}")
	INTELINSTR("vmovdqu64 %s, [r8]", "zmm9{k1}{z}")
	PLAN9INSTR("")

	INTELINSTR("vmovdqu64 %s, [rsi]", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm14")
	GFMULLXOR1("zmm10", "zmm11", "zmm4", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm17")
	GFMULLXOR2("zmm10", "zmm11", "zmm5", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm20")
	GFMULLXOR2("zmm10", "zmm11", "zmm6", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm23")
	GFMULLXOR2("zmm10", "zmm11", "zmm7", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm26")
	GFMULLXOR2("zmm10", "zmm11", "zmm8", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm29")
	GFMULLXOR2("zmm10", "zmm11", "zmm9", "zmm0")

	INTELINSTR("vmovdqu64 %s, [rax]", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm14")
	GFMULLXOR1("zmm10", "zmm11", "zmm4", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm17")
	GFMULLXOR2("zmm10", "zmm11", "zmm5", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm20")
	GFMULLXOR2("zmm10", "zmm11", "zmm6", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm23")
	GFMULLXOR2("zmm10", "zmm11", "zmm7", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm26")
	GFMULLXOR2("zmm10", "zmm11", "zmm8", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm29")
	GFMULLXOR2("zmm10", "zmm11", "zmm9", "zmm0")

	INTELINSTR("vmovdqu64 %s, [rbx]", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm15")
	GFMULLXOR1("zmm10", "zmm11", "zmm4", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm18")
	GFMULLXOR2("zmm10", "zmm11", "zmm5", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm21")
	GFMULLXOR2("zmm10", "zmm11", "zmm6", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm24")
	GFMULLXOR2("zmm10", "zmm11", "zmm7", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm27")
	GFMULLXOR2("zmm10", "zmm11", "zmm8", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm30")
	GFMULLXOR2("zmm10", "zmm11", "zmm9", "zmm0")

	INTELINSTR("vmovdqu64 %s, [r11]", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm15")
	GFMULLXOR1("zmm10", "zmm11", "zmm4", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm18")
	GFMULLXOR2("zmm10", "zmm11", "zmm5", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm21")
	GFMULLXOR2("zmm10", "zmm11", "zmm6", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm24")
	GFMULLXOR2("zmm10", "zmm11", "zmm7", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm27")
	GFMULLXOR2("zmm10", "zmm11", "zmm8", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm30")
	GFMULLXOR2("zmm10", "zmm11", "zmm9", "zmm0")

	INTELINSTR("vmovdqu64 %s, [r13]", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm16")
	GFMULLXOR1("zmm10", "zmm11", "zmm4", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm19")
	GFMULLXOR2("zmm10", "zmm11", "zmm5", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm22")
	GFMULLXOR2("zmm10", "zmm11", "zmm6", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm25")
	GFMULLXOR2("zmm10", "zmm11", "zmm7", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm28")
	GFMULLXOR2("zmm10", "zmm11", "zmm8", "zmm0")
	MULCONSTLS("zmm10", "zmm11", "zmm31")
	GFMULLXOR2("zmm10", "zmm11", "zmm9", "zmm0")

	INTELINSTR("vmovdqu64 %s, [r14]", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm16")
	GFMULLXOR1("zmm10", "zmm11", "zmm4", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm19")
	GFMULLXOR2("zmm10", "zmm11", "zmm5", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm22")
	GFMULLXOR2("zmm10", "zmm11", "zmm6", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm25")
	GFMULLXOR2("zmm10", "zmm11", "zmm7", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm28")
	GFMULLXOR2("zmm10", "zmm11", "zmm8", "zmm0")
	MULCONSTMS("zmm10", "zmm11", "zmm31")
	GFMULLXOR2("zmm10", "zmm11", "zmm9", "zmm0")

	INTELINSTR("vmovdqu64 [rdx], %s", "zmm4")
	INTELINSTR("vmovdqu64 [rcx], %s", "zmm5")
	INTELINSTR("vmovdqu64 [r10], %s", "zmm6")
	INTELINSTR("vmovdqu64 [r12], %s", "zmm7")
	INTELINSTR("vmovdqu64 [r15], %s", "zmm8")
	INTELINSTR("vmovdqu64 [r8], %s", "zmm9")
	PLAN9INSTR("")
	PLAN9INSTR("ADDQ $64, SI")  // in+=64")
	PLAN9INSTR("ADDQ $64, AX")  // in2+=64")
	PLAN9INSTR("ADDQ $64, BX")  // in3+=64")
	PLAN9INSTR("ADDQ $64, DX")  // out+=64")
	PLAN9INSTR("ADDQ $64, CX")  // out2+=64")
	PLAN9INSTR("ADDQ $64, R10") // out3+=64")
	PLAN9INSTR("ADDQ $64, R11") // in4+=64")
	PLAN9INSTR("ADDQ $64, R12") // out4+=64")
	PLAN9INSTR("ADDQ $64, R13") // in5+=64")
	PLAN9INSTR("ADDQ $64, R14") // in6+=64")
	PLAN9INSTR("ADDQ $64, R15") // in7+=64")
	PLAN9INSTR("ADDQ $64, R8") // in8+=64")
	PLAN9INSTR("")
	PLAN9INSTR("SUBQ $1, R9")
	PLAN9INSTR("JNZ loopback_avx512_parallel%s", config)
	PLAN9INSTR("")
	PLAN9LABEL("done_avx512_parallel%s:", config)
	PLAN9INSTR("VZEROUPPER")
	PLAN9INSTR("RET")
}

func AVX512XorParallel57() {

	// Register usage
	// ZMM16 - ZMM31: multiplication table

	const config = "57"

	// func galMulAVX512Parallel66(in, out [][]byte, matrix []byte, clear bool)
	PLAN9LABEL("TEXT ·galMulAVX512Parallel%s(SB), 7, $0", config)
	PLAN9INSTR("MOVQ  in+0(FP), SI     // ")
	PLAN9INSTR("MOVQ  8(SI), R9        // R9: len(in)")
	PLAN9INSTR("SHRQ  $6, R9           // len(in) / 64")
	PLAN9INSTR("TESTQ R9, R9")
	PLAN9INSTR("JZ    done_avx512_parallel%s", config)
	PLAN9INSTR("")

	// Load multiplication constants into registers
	PLAN9INSTR("MOVQ matrix+48(FP), SI")
	INTELINSTR("VMOVDQU64 ZMM14, 0x000[rsi]")
	INTELINSTR("VMOVDQU64 ZMM15, 0x040[rsi]")
	INTELINSTR("VMOVDQU64 ZMM16, 0x080[rsi]")
	INTELINSTR("VMOVDQU64 ZMM17, 0x0c0[rsi]")
	INTELINSTR("VMOVDQU64 ZMM18, 0x100[rsi]")
	INTELINSTR("VMOVDQU64 ZMM19, 0x140[rsi]")
	INTELINSTR("VMOVDQU64 ZMM20, 0x180[rsi]")
	INTELINSTR("VMOVDQU64 ZMM21, 0x1c0[rsi]")
	INTELINSTR("VMOVDQU64 ZMM22, 0x200[rsi]")
	INTELINSTR("VMOVDQU64 ZMM23, 0x240[rsi]")
	INTELINSTR("VMOVDQU64 ZMM24, 0x280[rsi]")
	INTELINSTR("VMOVDQU64 ZMM25, 0x2c0[rsi]")
	INTELINSTR("VMOVDQU64 ZMM26, 0x300[rsi]")
	INTELINSTR("VMOVDQU64 ZMM27, 0x340[rsi]")
	INTELINSTR("VMOVDQU64 ZMM28, 0x380[rsi]")
	INTELINSTR("VMOVDQU64 ZMM29, 0x3c0[rsi]")
	INTELINSTR("VMOVDQU64 ZMM30, 0x400[rsi]")
	INTELINSTR("VMOVDQU64 ZMM31, 0x440[rsi]")

	MULMASK("ZMM2")
	PLAN9INSTR("")

	// Set k1 mask to either load or clear existing output
	PLAN9INSTR("MOVB xor+72(FP), AX")
	INTELINSTR("mov r8, -1")
	INTELINSTR("mul r8")
	INTELINSTR("kmovq k1, rax")

	// Load pointers for input
	PLAN9INSTR("MOVQ in+0(FP), SI  //  SI: &in")
	PLAN9INSTR("MOVQ 24(SI), AX    //  AX: &in[1][0]")
	PLAN9INSTR("MOVQ 48(SI), BX    //  BX: &in[2][0]")
	PLAN9INSTR("MOVQ 72(SI), R11   // R11: &in[3][0]")
	PLAN9INSTR("MOVQ 96(SI), R13   // R13: &in[4][0]")
	PLAN9INSTR("MOVQ (SI), SI      //  SI: &in[0][0]")

	// Load pointers for output
	PLAN9INSTR("MOVQ out+24(FP), DX")
	PLAN9INSTR("MOVQ 24(DX), CX    //  CX: &out[1][0]")
	PLAN9INSTR("MOVQ 48(DX), R10   // R10: &out[2][0]")
	PLAN9INSTR("MOVQ 72(DX), R12   // R12: &out[3][0]")
	PLAN9INSTR("MOVQ 96(DX), R15   // R15: &out[4][0]")
	PLAN9INSTR("MOVQ 120(DX), R8   //  R8: &out[5][0]")
	PLAN9INSTR("MOVQ 144(DX), R14  // R14: &out[6][0]")
	PLAN9INSTR("MOVQ (DX), DX      //  DX: &out[0][0]")
	PLAN9INSTR("")

	// Main loop
	PLAN9LABEL("loopback_avx512_parallel%s:", config)
	INTELINSTR("VMOVDQU64 %s, [rdx]", "ZMM4{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [rcx]", "ZMM5{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [r10]", "ZMM6{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [r12]", "ZMM7{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [r15]", "ZMM8{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [r8]", "ZMM9{k1}{z}")
	INTELINSTR("VMOVDQU64 %s, [r14]", "ZMM12{k1}{z}")
	PLAN9INSTR("")

	INTELINSTR("VMOVDQU64 %s, [rsi]", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM14")
	GFMULLXOR1("ZMM10", "ZMM11", "ZMM4", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM16")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM5", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM19")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM21")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM7", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM24")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM8", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM26")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM9", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM29")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM12", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [rax]", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM14")
	GFMULLXOR1("ZMM10", "ZMM11", "ZMM4", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM17")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM5", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM19")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM22")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM7", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM24")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM8", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM27")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM9", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM29")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM12", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [rbx]", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM15")
	GFMULLXOR1("ZMM10", "ZMM11", "ZMM4", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM17")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM5", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM20")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM22")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM7", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM25")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM8", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM27")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM9", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM30")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM12", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [r11]", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM15")
	GFMULLXOR1("ZMM10", "ZMM11", "ZMM4", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM18")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM5", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM20")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM23")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM7", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM25")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM8", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM28")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM9", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM30")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM12", "ZMM0")

	INTELINSTR("VMOVDQU64 %s, [r13]", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM16")
	GFMULLXOR1("ZMM10", "ZMM11", "ZMM4", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM18")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM5", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM21")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM6", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM23")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM7", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM26")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM8", "ZMM0")
	MULCONSTMS("ZMM10", "ZMM11", "ZMM28")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM9", "ZMM0")
	MULCONSTLS("ZMM10", "ZMM11", "ZMM31")
	GFMULLXOR2("ZMM10", "ZMM11", "ZMM12", "ZMM0")

	INTELINSTR("VMOVDQU64 [rdx], %s", "ZMM4")
	INTELINSTR("VMOVDQU64 [rcx], %s", "ZMM5")
	INTELINSTR("VMOVDQU64 [r10], %s", "ZMM6")
	INTELINSTR("VMOVDQU64 [r12], %s", "ZMM7")
	INTELINSTR("VMOVDQU64 [r15], %s", "ZMM8")
	INTELINSTR("VMOVDQU64 [r8], %s", "ZMM9")
	INTELINSTR("VMOVDQU64 [r14], %s", "ZMM12")
	PLAN9INSTR("")
	PLAN9INSTR("ADDQ $64, SI  // in+=64")
	PLAN9INSTR("ADDQ $64, AX  // in2+=64")
	PLAN9INSTR("ADDQ $64, BX  // in3+=64")
	PLAN9INSTR("ADDQ $64, DX  // out+=64")
	PLAN9INSTR("ADDQ $64, CX  // out2+=64")
	PLAN9INSTR("ADDQ $64, R10 // out3+=64")
	PLAN9INSTR("ADDQ $64, R11 // in4+=64")
	PLAN9INSTR("ADDQ $64, R12 // out4+=64")
	PLAN9INSTR("ADDQ $64, R13 // in5+=64")
	PLAN9INSTR("ADDQ $64, R14 // in6+=64")
	PLAN9INSTR("ADDQ $64, R15 // in7+=64")
	PLAN9INSTR("ADDQ $64, R8 // in8+=64")
	PLAN9INSTR("")
	PLAN9INSTR("SUBQ $1, R9")
	PLAN9INSTR("JNZ  loopback_avx512_parallel%s", config)
	PLAN9INSTR("")
	PLAN9LABEL("done_avx512_parallel%s:", config)
	PLAN9INSTR("VZEROUPPER")
	PLAN9INSTR("RET")
}

func main() {
	//AVX512XorParallel84()
	AVX512XorParallel66()
	//AVX512XorParallel57()

}