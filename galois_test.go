/**
 * Unit tests for Galois
 *
 * Copyright 2015, Klaus Post
 * Copyright 2015, Backblaze, Inc.
 */

package reedsolomon

import (
	"bytes"
	"testing"
	"fmt"
	"math/rand"
	"sync"
)

func TestAssociativity(t *testing.T) {
	for i := 0; i < 256; i++ {
		a := byte(i)
		for j := 0; j < 256; j++ {
			b := byte(j)
			for k := 0; k < 256; k++ {
				c := byte(k)
				x := galAdd(a, galAdd(b, c))
				y := galAdd(galAdd(a, b), c)
				if x != y {
					t.Fatal("add does not match:", x, "!=", y)
				}
				x = galMultiply(a, galMultiply(b, c))
				y = galMultiply(galMultiply(a, b), c)
				if x != y {
					t.Fatal("multiply does not match:", x, "!=", y)
				}
			}
		}
	}
}

func TestIdentity(t *testing.T) {
	for i := 0; i < 256; i++ {
		a := byte(i)
		b := galAdd(a, 0)
		if a != b {
			t.Fatal("Add zero should yield same result", a, "!=", b)
		}
		b = galMultiply(a, 1)
		if a != b {
			t.Fatal("Mul by one should yield same result", a, "!=", b)
		}
	}
}

func TestInverse(t *testing.T) {
	for i := 0; i < 256; i++ {
		a := byte(i)
		b := galSub(0, a)
		c := galAdd(a, b)
		if c != 0 {
			t.Fatal("inverse sub/add", c, "!=", 0)
		}
		if a != 0 {
			b = galDivide(1, a)
			c = galMultiply(a, b)
			if c != 1 {
				t.Fatal("inverse div/mul", c, "!=", 1)
			}
		}
	}
}

func TestCommutativity(t *testing.T) {
	for i := 0; i < 256; i++ {
		a := byte(i)
		for j := 0; j < 256; j++ {
			b := byte(j)
			x := galAdd(a, b)
			y := galAdd(b, a)
			if x != y {
				t.Fatal(x, "!= ", y)
			}
			x = galMultiply(a, b)
			y = galMultiply(b, a)
			if x != y {
				t.Fatal(x, "!= ", y)
			}
		}
	}
}

func TestDistributivity(t *testing.T) {
	for i := 0; i < 256; i++ {
		a := byte(i)
		for j := 0; j < 256; j++ {
			b := byte(j)
			for k := 0; k < 256; k++ {
				c := byte(k)
				x := galMultiply(a, galAdd(b, c))
				y := galAdd(galMultiply(a, b), galMultiply(a, c))
				if x != y {
					t.Fatal(x, "!= ", y)
				}
			}
		}
	}
}

func TestExp(t *testing.T) {
	for i := 0; i < 256; i++ {
		a := byte(i)
		power := byte(1)
		for j := 0; j < 256; j++ {
			x := galExp(a, j)
			if x != power {
				t.Fatal(x, "!=", power)
			}
			power = galMultiply(power, a)
		}
	}
}

func testGalois(t *testing.T, ssse3, avx2 bool) {
	// These values were copied output of the Python code.
	if galMultiply(3, 4) != 12 {
		t.Fatal("galMultiply(3, 4) != 12")
	}
	if galMultiply(7, 7) != 21 {
		t.Fatal("galMultiply(7, 7) != 21")
	}
	if galMultiply(23, 45) != 41 {
		t.Fatal("galMultiply(23, 45) != 41")
	}

	// Test slices (>32 entries to test assembler -- AVX2 & NEON)
	in := []byte{0, 1, 2, 3, 4, 5, 6, 10, 50, 100, 150, 174, 201, 255, 99, 32, 67, 85, 200, 199, 198, 197, 196, 195, 194, 193, 192, 191, 190, 189, 188, 187, 186, 185}
	out := make([]byte, len(in))
	galMulSlice(25, in, out, ssse3, avx2)
	expect := []byte{0x0, 0x19, 0x32, 0x2b, 0x64, 0x7d, 0x56, 0xfa, 0xb8, 0x6d, 0xc7, 0x85, 0xc3, 0x1f, 0x22, 0x7, 0x25, 0xfe, 0xda, 0x5d, 0x44, 0x6f, 0x76, 0x39, 0x20, 0xb, 0x12, 0x11, 0x8, 0x23, 0x3a, 0x75, 0x6c, 0x47}
	if 0 != bytes.Compare(out, expect) {
		t.Errorf("got %#v, expected %#v", out, expect)
	}
	expectXor := []byte{0x0, 0x2d, 0x5a, 0x77, 0xb4, 0x99, 0xee, 0x2f, 0x79, 0xf2, 0x7, 0x51, 0xd4, 0x19, 0x31, 0xc9, 0xf8, 0xfc, 0xf9, 0x4f, 0x62, 0x15, 0x38, 0xfb, 0xd6, 0xa1, 0x8c, 0x96, 0xbb, 0xcc, 0xe1, 0x22, 0xf, 0x78}
	galMulSliceXor(52, in, out, ssse3, avx2)
	if 0 != bytes.Compare(out, expectXor) {
		t.Errorf("got %#v, expected %#v", out, expectXor)
	}

	galMulSlice(177, in, out, ssse3, avx2)
	expect = []byte{0x0, 0xb1, 0x7f, 0xce, 0xfe, 0x4f, 0x81, 0x9e, 0x3, 0x6, 0xe8, 0x75, 0xbd, 0x40, 0x36, 0xa3, 0x95, 0xcb, 0xc, 0xdd, 0x6c, 0xa2, 0x13, 0x23, 0x92, 0x5c, 0xed, 0x1b, 0xaa, 0x64, 0xd5, 0xe5, 0x54, 0x9a}
	if 0 != bytes.Compare(out, expect) {
		t.Errorf("got %#v, expected %#v", out, expect)
	}

	expectXor = []byte{0x0, 0xc4, 0x95, 0x51, 0x37, 0xf3, 0xa2, 0xfb, 0xec, 0xc5, 0xd0, 0xc7, 0x53, 0x88, 0xa3, 0xa5, 0x6, 0x78, 0x97, 0x9f, 0x5b, 0xa, 0xce, 0xa8, 0x6c, 0x3d, 0xf9, 0xdf, 0x1b, 0x4a, 0x8e, 0xe8, 0x2c, 0x7d}
	galMulSliceXor(117, in, out, ssse3, avx2)
	if 0 != bytes.Compare(out, expectXor) {
		t.Errorf("got %#v, expected %#v", out, expectXor)
	}

	if galExp(2, 2) != 4 {
		t.Fatal("galExp(2, 2) != 4")
	}
	if galExp(5, 20) != 235 {
		t.Fatal("galExp(5, 20) != 235")
	}
	if galExp(13, 7) != 43 {
		t.Fatal("galExp(13, 7) != 43")
	}
}

func TestGalois(t *testing.T) {
	// invoke will all combinations of asm instructions
	testGalois(t, false, false)
	testGalois(t, true, false)
	testGalois(t, false, true)
}

func TestSliceGalADD(t *testing.T) {

	lengthList := []int{16, 32, 34}
	for _, length := range lengthList {
		in := make([]byte, length)
		fillRandom(in)
		out := make([]byte, length)
		fillRandom(out)
		expect := make([]byte, length)
		for i := range expect {
			expect[i] = in[i] ^ out[i]
		}
		sliceXor(in, out, false)
		if 0 != bytes.Compare(out, expect) {
			t.Errorf("got %#v, expected %#v", out, expect)
		}
		fillRandom(out)
		for i := range expect {
			expect[i] = in[i] ^ out[i]
		}
		sliceXor(in, out, true)
		if 0 != bytes.Compare(out, expect) {
			t.Errorf("got %#v, expected %#v", out, expect)
		}
	}

	for i := 0; i < 256; i++ {
		a := byte(i)
		for j := 0; j < 256; j++ {
			b := byte(j)
			for k := 0; k < 256; k++ {
				c := byte(k)
				x := galAdd(a, galAdd(b, c))
				y := galAdd(galAdd(a, b), c)
				if x != y {
					t.Fatal("add does not match:", x, "!=", y)
				}
				x = galMultiply(a, galMultiply(b, c))
				y = galMultiply(galMultiply(a, b), c)
				if x != y {
					t.Fatal("multiply does not match:", x, "!=", y)
				}
			}
		}
	}
}

func benchmarkGalois(b *testing.B, size int) {
	in := make([]byte, size)
	out := make([]byte, size)

	b.SetBytes(int64(size))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSlice(25, in[:], out[:], false, true)
	}
}

func BenchmarkGalois128K(b *testing.B) {
	benchmarkGalois(b, 128*1024)
}

func BenchmarkGalois1M(b *testing.B) {
	benchmarkGalois(b, 1024*1024)
}

func benchmarkGaloisXor(b *testing.B, size int) {
	in := make([]byte, size)
	out := make([]byte, size)

	b.SetBytes(int64(size))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXor(177, in[:], out[:], false, true)
	}
}

func BenchmarkGaloisXor128K(b *testing.B) {
	benchmarkGaloisXor(b, 128*1024)
}

func BenchmarkGaloisXor1M(b *testing.B) {
	benchmarkGaloisXor(b, 1024*1024)
}

func BenchmarkGaloisXor10M(b *testing.B) {
	benchmarkGaloisXor(b, 10*1024*1024)
}

func benchmarkGaloisXorParallel2(b *testing.B, size int) {
	in := make([]byte, size)
	in2 := make([]byte, size)
	out := make([]byte, size)

	opts := defaultOptions
	opts.useSSSE3 = true

	b.SetBytes(int64(size * 2))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXorParallel2(177, in[:], out[:], in2[:], false, true)
	}
}

func BenchmarkGaloisXorParallel2_10M(b *testing.B) {
	benchmarkGaloisXorParallel2(b, 10*1024*1024)
}

func benchmarkGaloisXorParallel3(b *testing.B, size int) {
	in := make([]byte, size)
	in2 := make([]byte, size)
	in3 := make([]byte, size)
	out := make([]byte, size)

	opts := defaultOptions
	opts.useSSSE3 = true

	b.SetBytes(int64(size * 3))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXorParallel3(177, in[:], out[:], in2[:], in3[:], false, true)
	}
}

func BenchmarkGaloisXorParallel3_10M(b *testing.B) {
	benchmarkGaloisXorParallel3(b, 10*1024*1024)
}

func benchmarkGaloisXorParallel4(b *testing.B, size int) {
	in := make([]byte, size)
	in2 := make([]byte, size)
	in3 := make([]byte, size)
	in4 := make([]byte, size)
	out := make([]byte, size)

	opts := defaultOptions
	opts.useSSSE3 = true

	b.SetBytes(int64(size * 4))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXorParallel4(177, in[:], out[:], in2[:], in3[:], in4[:], false, true)
	}
}

func BenchmarkGaloisXorParallel4_10M(b *testing.B) {
	benchmarkGaloisXorParallel4(b, 10*1024*1024)
}

func benchmarkGaloisXorParallel22(b *testing.B, size int) {
	in := make([]byte, size)
	in2 := make([]byte, size)
	out := make([]byte, size)
	out2 := make([]byte, size)

	opts := defaultOptions
	opts.useSSSE3 = true

	b.SetBytes(int64(size * 4))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXorParallel22(177, 25, in[:], out[:], in2[:], out2[:], false, true)
	}
}

func BenchmarkGaloisXorParallel22_10M(b *testing.B) {
	benchmarkGaloisXorParallel22(b, 10*1024*1024)
}

func benchmarkGaloisXorParallel33(b *testing.B, size int) {
	in := make([]byte, size)
	in2 := make([]byte, size)
	in3 := make([]byte, size)
	out := make([]byte, size)
	out2 := make([]byte, size)
	out3 := make([]byte, size)

	opts := defaultOptions
	opts.useSSSE3 = true

	b.SetBytes(int64(size * 9))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXorParallel33(177, 25, 87, in[:], out[:], in2[:], out2[:], in3[:], out3[:], false, true)
	}
}

func BenchmarkGaloisXorParallel33_10M(b *testing.B) {
	benchmarkGaloisXorParallel33(b, 10*1024*1024)
}

func benchmarkGaloisXorParallel44(b *testing.B, size int) {
	in := make([]byte, size)
	in2 := make([]byte, size)
	in3 := make([]byte, size)
	in4 := make([]byte, size)
	out := make([]byte, size)
	out2 := make([]byte, size)
	out3 := make([]byte, size)
	out4 := make([]byte, size)

	opts := defaultOptions
	opts.useSSSE3 = true

	b.SetBytes(int64(size * 16))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXorParallel44(177, 25, 87, 111, in[:], out[:], in2[:], out2[:], in3[:], out3[:], in4[:], out4[:], false, true)
	}
}

func BenchmarkGaloisXorParallel44_10M(b *testing.B) {
	benchmarkGaloisXorParallel44(b, 10*1024*1024)
}

func benchmarkGaloisXor512Parallel44(b *testing.B, size int) {
	in := make([]byte, size)
	in2 := make([]byte, size)
	in3 := make([]byte, size)
	in4 := make([]byte, size)
	out := make([]byte, size)
	out2 := make([]byte, size)
	out3 := make([]byte, size)
	out4 := make([]byte, size)

	opts := defaultOptions
	opts.useSSSE3 = true

	b.SetBytes(int64(size * 16))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		galMulSliceXor512Parallel44(177, 25, 87, 111, in[:], out[:], in2[:], out2[:], in3[:], out3[:], in4[:], out4[:], false, true)
	}
}

func BenchmarkGaloisXor512Parallel44_10M(b *testing.B) {
	benchmarkGaloisXor512Parallel44(b, 10*1024*1024)
}

func TestGaloisAvx512Parallel84(t *testing.T) {

	if !defaultOptions.useAVX512 {
		return
	}

	size := 1024 * 1024
	in1 := make([]byte, size)
	in2 := make([]byte, size)
	in3 := make([]byte, size)
	in4 := make([]byte, size)
	in5 := make([]byte, size)
	in6 := make([]byte, size)
	in7 := make([]byte, size)
	in8 := make([]byte, size)
	out1 := make([]byte, size)
	out2 := make([]byte, size)
	out3 := make([]byte, size)
	out4 := make([]byte, size)

	rand.Read(in1)
	rand.Read(in2)
	rand.Read(in3)
	rand.Read(in4)
	rand.Read(in5)
	rand.Read(in6)
	rand.Read(in7)
	rand.Read(in8)

	rand.Read(out1)
	rand.Read(out2)
	rand.Read(out3)
	rand.Read(out4)

	opts := defaultOptions
	opts.useSSSE3 = true

	in := make([][]byte, 8)
	in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7] = in1, in2, in3, in4, in5, in6, in7, in8
	out := make([][]byte, 4)
	out[0], out[1], out[2], out[3] = out1, out2, out3, out4

	matrix := make([]byte, (16+16)*len(in)*len(out))
	coeffs := make([]byte, len(in)*len(out))

	for i := 0; i < len(in)*len(out); i++ {
		coeffs[i] = byte(rand.Int31n(256))
		copy(matrix[i*32:], mulTableLow[coeffs[i]][:])
		copy(matrix[i*32+16:], mulTableHigh[coeffs[i]][:])
	}

	galMulAVX512Parallel84(in, out, matrix, false)

	verify1, verify2, verify3, verify4 := make([]byte, size), make([]byte, size), make([]byte, size), make([]byte, size)
	rand.Read(verify1)
	rand.Read(verify2)
	rand.Read(verify3)
	rand.Read(verify4)

	for i := range in {
		if i == 0 {
			galMulSlice(coeffs[i], in[i], verify1, false, false)
			galMulSlice(coeffs[8+i], in[i], verify2, false, false)
			galMulSlice(coeffs[16+i], in[i], verify3, false, false)
			galMulSlice(coeffs[24+i], in[i], verify4, false, false)
		} else {
			galMulSliceXor(coeffs[i], in[i], verify1, false, false)
			galMulSliceXor(coeffs[8+i], in[i], verify2, false, false)
			galMulSliceXor(coeffs[16+i], in[i], verify3, false, false)
			galMulSliceXor(coeffs[24+i], in[i], verify4, false, false)
		}
	}
	fmt.Println(out1[:10])
	fmt.Println(verify1[:10])

	fmt.Println(out2[:10])
	fmt.Println(verify2[:10])

	fmt.Println(out3[:10])
	fmt.Println(verify3[:10])

	fmt.Println(out4[:10])
	fmt.Println(verify4[:10])

	in9 := make([]byte, size)
	in10 := make([]byte, size)
	in11 := make([]byte, size)
	in12 := make([]byte, size)
	in13 := make([]byte, size)
	in14 := make([]byte, size)
	in15 := make([]byte, size)
	in16 := make([]byte, size)

	rand.Read(in9)
	rand.Read(in10)
	rand.Read(in11)
	rand.Read(in12)
	rand.Read(in13)
	rand.Read(in14)
	rand.Read(in15)
	rand.Read(in16)

	in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7] = in9, in10, in11, in12, in13, in14, in15, in16

	for i := 0; i < len(in)*len(out); i++ {
		coeffs[i] = byte(rand.Int31n(256))
		copy(matrix[i*32:], mulTableLow[coeffs[i]][:])
		copy(matrix[i*32+16:], mulTableHigh[coeffs[i]][:])
	}

	galMulAVX512Parallel84(in, out, matrix, true)

	for i := range in {
		galMulSliceXor(coeffs[i], in[i], verify1, false, false)
		galMulSliceXor(coeffs[8+i], in[i], verify2, false, false)
		galMulSliceXor(coeffs[16+i], in[i], verify3, false, false)
		galMulSliceXor(coeffs[24+i], in[i], verify4, false, false)
	}

	fmt.Println(out1[:10])
	fmt.Println(verify1[:10])

	fmt.Println(out2[:10])
	fmt.Println(verify2[:10])

	fmt.Println(out3[:10])
	fmt.Println(verify3[:10])

	fmt.Println(out4[:10])
	fmt.Println(verify4[:10])
}

func createArrays(dim, size int) (in [][]byte) {

	in = make([][]byte, dim)

	for d := 0; d < dim; d++ {
		in[d] = make([]byte, size)
		rand.Read(in[d])
	}

	return
}

func benchmarkGaloisEncode8x4x10M_AVX512_Parallel(b *testing.B, cores, size int) {

	const inDim = 8
	const outDim = 4

	in, out := make([][][]byte, cores), make([][][]byte, cores)
	for c := 0; c < cores; c++ {
		in[c] = createArrays(inDim, size)
		out[c] = createArrays(outDim, size)
	}

	matrix := make([]byte, (16+16)*inDim*outDim)
	coeffs := make([]byte, inDim*outDim)

	for i := 0; i < inDim*outDim; i++ {
		coeffs[i] = byte(rand.Int31n(256))
		copy(matrix[i*32:], mulTableLow[coeffs[i]][:])
		copy(matrix[i*32+16:], mulTableHigh[coeffs[i]][:])
	}

	b.SetBytes(int64(size * outDim * cores))
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		var wg sync.WaitGroup
		for c := 0; c < cores; c++ {
			wg.Add(1)
			go func(c int) { galMulAVX512Parallel84(in[c], out[c], matrix, false); wg.Done() }(c)
		}
		wg.Wait()
	}
}

func BenchmarkGaloisEncode8x4x10M_AVX512_2Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX512_Parallel(b, 2, 10*1024*1024)
}

func BenchmarkGaloisEncode8x4x10M_AVX512_3Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX512_Parallel(b, 3, 10*1024*1024)
}

func BenchmarkGaloisEncode8x4x10M_AVX512_4Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX512_Parallel(b, 4, 10*1024*1024)
}

func BenchmarkGaloisEncode8x4x10M_AVX512_6Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX512_Parallel(b, 6, 10*1024*1024)
}

func benchmarkGaloisEncode8x4x10M_AVX2(b *testing.B, cores, size int) {

	const inDim = 8
	const outDim = 4

	in, out := make([][][]byte, cores), make([][][]byte, cores)
	for c := 0; c < cores; c++ {
		in[c] = createArrays(inDim, size)
		out[c] = createArrays(outDim, size)
	}

	coeffs := make([]byte, inDim*outDim)

	for i := 0; i < inDim*outDim; i++ {
		coeffs[i] = byte(rand.Int31n(256))
	}

	b.SetBytes(int64(size * outDim * cores))
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var wg sync.WaitGroup
		for c := 0; c < cores; c++ {
			wg.Add(1)
			go func(c int) {
				for i := range in[c] {
					if i == 0 {
						galMulSlice(coeffs[i], in[c][i], out[c][0], false, true)
						galMulSlice(coeffs[8+i], in[c][i], out[c][1], false, true)
						galMulSlice(coeffs[16+i], in[c][i], out[c][2], false, true)
						galMulSlice(coeffs[24+i], in[c][i], out[c][3], false, true)
					} else {
						galMulSliceXor(coeffs[i], in[c][i], out[c][0], false, true)
						galMulSliceXor(coeffs[8+i], in[c][i], out[c][1], false, true)
						galMulSliceXor(coeffs[16+i], in[c][i], out[c][2], false, true)
						galMulSliceXor(coeffs[24+i], in[c][i], out[c][3], false, true)
					}
				}
				wg.Done()
			}(c)
		}
		wg.Wait()
	}
}

func BenchmarkGaloisEncode8x4x10M_AVX2(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX2(b, 1, 10*1024*1024)
}

func BenchmarkGaloisEncode8x4x10M_AVX2_2Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX2(b, 2, 10*1024*1024)
}

func BenchmarkGaloisEncode8x4x10M_AVX2_3Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX2(b, 3, 10*1024*1024)
}

func BenchmarkGaloisEncode8x4x10M_AVX2_4Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX2(b, 4, 10*1024*1024)
}

func BenchmarkGaloisEncode8x4x10M_AVX2_6Cores(b *testing.B) {
	benchmarkGaloisEncode8x4x10M_AVX2(b, 6, 10*1024*1024)
}

func benchmarkGaloisEncode6x6x10M_AVX512_Parallel(b *testing.B, cores, size int) {

	const inDim = 6
	const outDim = 6

	in, out := make([][][]byte, cores), make([][][]byte, cores)
	for c := 0; c < cores; c++ {
		in[c] = createArrays(inDim, size)
		out[c] = createArrays(outDim, size)
	}

	matrix := make([]byte, (16+16)*inDim*outDim)
	coeffs := make([]byte, inDim*outDim)

	for i := 0; i < inDim*outDim; i++ {
		coeffs[i] = byte(rand.Int31n(256))
		copy(matrix[i*32:], mulTableLow[coeffs[i]][:])
		copy(matrix[i*32+16:], mulTableHigh[coeffs[i]][:])
	}

	b.SetBytes(int64(size * outDim * cores))
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		var wg sync.WaitGroup
		for c := 0; c < cores; c++ {
			wg.Add(1)
			go func(c int) { galMulAVX512Parallel66(in[c], out[c], matrix, false); wg.Done() }(c)
		}
		wg.Wait()
	}
}

func BenchmarkGaloisEncode6x6x10M_AVX512(b *testing.B) {
	benchmarkGaloisEncode6x6x10M_AVX512_Parallel(b, 1, 10*1024*1024)
}

func BenchmarkGaloisEncode6x6x10M_AVX512_2Cores(b *testing.B) {
	benchmarkGaloisEncode6x6x10M_AVX512_Parallel(b, 2, 10*1024*1024)
}

func BenchmarkGaloisEncode6x6x10M_AVX512_3Cores(b *testing.B) {
	benchmarkGaloisEncode6x6x10M_AVX512_Parallel(b, 3, 10*1024*1024)
}

func benchmarkGaloisEncode6x6x10M_AVX2(b *testing.B, cores, size int) {

	const inDim = 6
	const outDim = 6

	in, out := make([][][]byte, cores), make([][][]byte, cores)
	for c := 0; c < cores; c++ {
		in[c] = createArrays(inDim, size)
		out[c] = createArrays(outDim, size)
	}

	coeffs := make([]byte, inDim*outDim)

	for i := 0; i < inDim*outDim; i++ {
		coeffs[i] = byte(rand.Int31n(256))
	}

	b.SetBytes(int64(size * outDim * cores))
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var wg sync.WaitGroup
		for c := 0; c < cores; c++ {
			wg.Add(1)
			go func(c int) {
				for i := range in[c] {
					if i == 0 {
						galMulSlice(coeffs[i], in[c][i], out[c][0], false, true)
						galMulSlice(coeffs[6+i], in[c][i], out[c][1], false, true)
						galMulSlice(coeffs[12+i], in[c][i], out[c][2], false, true)
						galMulSlice(coeffs[18+i], in[c][i], out[c][3], false, true)
						galMulSlice(coeffs[24+i], in[c][i], out[c][3], false, true)
						galMulSlice(coeffs[30+i], in[c][i], out[c][3], false, true)
					} else {
						galMulSliceXor(coeffs[i], in[c][i], out[c][0], false, true)
						galMulSliceXor(coeffs[6+i], in[c][i], out[c][1], false, true)
						galMulSliceXor(coeffs[12+i], in[c][i], out[c][2], false, true)
						galMulSliceXor(coeffs[18+i], in[c][i], out[c][3], false, true)
						galMulSliceXor(coeffs[24+i], in[c][i], out[c][3], false, true)
						galMulSliceXor(coeffs[30+i], in[c][i], out[c][3], false, true)
					}
				}
				wg.Done()
			}(c)
		}
		wg.Wait()
	}
}

func BenchmarkGaloisEncode6x6x10M_AVX2(b *testing.B) {
	benchmarkGaloisEncode6x6x10M_AVX2(b, 1, 10*1024*1024)
}

func BenchmarkGaloisEncode6x6x10M_AVX2_2Cores(b *testing.B) {
	benchmarkGaloisEncode6x6x10M_AVX2(b, 2, 10*1024*1024)
}

func BenchmarkGaloisEncode6x6x10M_AVX2_3Cores(b *testing.B) {
	benchmarkGaloisEncode6x6x10M_AVX2(b, 3, 10*1024*1024)
}

func benchmarkGaloisEncode5x7x10M_AVX512_Parallel(b *testing.B, cores, size int) {

	const inDim = 5
	const outDim = 7

	in, out := make([][][]byte, cores), make([][][]byte, cores)
	for c := 0; c < cores; c++ {
		in[c] = createArrays(inDim, size)
		out[c] = createArrays(outDim, size)
	}

	matrix := make([]byte, ((16+16)*inDim*outDim+31)&^31)
	coeffs := make([]byte, inDim*outDim)

	for i := 0; i < inDim*outDim; i++ {
		coeffs[i] = byte(rand.Int31n(256))
		copy(matrix[i*32:], mulTableLow[coeffs[i]][:])
		copy(matrix[i*32+16:], mulTableHigh[coeffs[i]][:])
	}

	b.SetBytes(int64(size * outDim * cores))
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		var wg sync.WaitGroup
		for c := 0; c < cores; c++ {
			wg.Add(1)
			go func(c int) { galMulAVX512Parallel57(in[c], out[c], matrix, false); wg.Done() }(c)
		}
		wg.Wait()
	}
}

func BenchmarkGaloisEncode5x7x10M_AVX512(b *testing.B) {
	benchmarkGaloisEncode5x7x10M_AVX512_Parallel(b, 1, 10*1024*1024)
}

func BenchmarkGaloisEncode5x7x10M_AVX512_2Cores(b *testing.B) {
	benchmarkGaloisEncode5x7x10M_AVX512_Parallel(b, 2, 10*1024*1024)
}

func benchmarkGaloisEncode5x7x10M_AVX2(b *testing.B, cores, size int) {

	const inDim = 5
	const outDim = 7

	in, out := make([][][]byte, cores), make([][][]byte, cores)
	for c := 0; c < cores; c++ {
		in[c] = createArrays(inDim, size)
		out[c] = createArrays(outDim, size)
	}

	coeffs := make([]byte, inDim*outDim)

	for i := 0; i < inDim*outDim; i++ {
		coeffs[i] = byte(rand.Int31n(256))
	}

	b.SetBytes(int64(size * outDim * cores))
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var wg sync.WaitGroup
		for c := 0; c < cores; c++ {
			wg.Add(1)
			go func(c int) {
				for i := range in[c] {
					if i == 0 {
						galMulSlice(coeffs[i], in[c][i], out[c][0], false, true)
						galMulSlice(coeffs[6+i], in[c][i], out[c][1], false, true)
						galMulSlice(coeffs[12+i], in[c][i], out[c][2], false, true)
						galMulSlice(coeffs[18+i], in[c][i], out[c][3], false, true)
						galMulSlice(coeffs[24+i], in[c][i], out[c][3], false, true)
						galMulSlice(coeffs[30+i], in[c][i], out[c][3], false, true)
					} else {
						galMulSliceXor(coeffs[i], in[c][i], out[c][0], false, true)
						galMulSliceXor(coeffs[6+i], in[c][i], out[c][1], false, true)
						galMulSliceXor(coeffs[12+i], in[c][i], out[c][2], false, true)
						galMulSliceXor(coeffs[18+i], in[c][i], out[c][3], false, true)
						galMulSliceXor(coeffs[24+i], in[c][i], out[c][3], false, true)
						galMulSliceXor(coeffs[30+i], in[c][i], out[c][3], false, true)
					}
				}
				wg.Done()
			}(c)
		}
		wg.Wait()
	}
}

func BenchmarkGaloisEncode5x7x10M_AVX2(b *testing.B) {
	benchmarkGaloisEncode5x7x10M_AVX2(b, 1, 10*1024*1024)
}
