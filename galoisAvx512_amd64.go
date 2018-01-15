//+build !noasm
//+build !appengine

// Copyright 2015, Klaus Post, see LICENSE for details.
// Copyright 2017, Minio, Inc.

package reedsolomon

import "fmt"

//go:noescape
func _galMulAVX512Parallel84(in, out [][]byte, matrix *[(16 + 16) * 8 * 4]byte, addTo bool)

func galMulAVX512Parallel84(in, out [][]byte, matrixRows [][]byte, inputOffset, outputOffset int) {

	done := len(in[0])
	if done > 0 {
		inputEnd := inputOffset + dimIn84
		if inputEnd > len(in) {
			inputEnd = len(in)
		}
		outputEnd := outputOffset + dimOut84
		if outputEnd > len(out) {
			outputEnd = len(out)
		}

		matrix84 := [(16 + 16) * dimIn84 * dimOut84]byte{}
		setupMatrix84(matrixRows, inputOffset, outputOffset, &matrix84)
		addTo := inputOffset != 0 // Except for the first input column, add to previous results
		_galMulAVX512Parallel84(in[inputOffset:inputEnd], out[outputOffset:outputEnd], &matrix84, addTo)

		done = (done >> 6) << 6
	}
	remain := len(in[0]) - done

	if remain > 0 {
		for c := inputOffset; c < inputOffset+dimIn84; c++ {
			for iRow := outputOffset; iRow < outputOffset+dimOut84; iRow++ {
				if c < len(matrixRows[iRow]) {
					mt := mulTable[matrixRows[iRow][c]]
					for i := done; i < len(in[0]); i++ {
						if c == 0 { // only set value for first input column
							out[iRow][i] = mt[in[c][i]]
						} else { // and add for all others
							out[iRow][i] ^= mt[in[c][i]]
						}
					}
				}
			}
		}
	}
}

const dimIn84 = 8
const dimOut84 = 4

var zeroCoeff = [16]byte{}

func setupMatrix84(matrixRows [][]byte, inputOffset, outputOffset int, matrix *[(16 + 16) * dimIn84 * dimOut84]byte) {

	offset := 0
	for c := inputOffset; c < inputOffset+dimIn84; c++ {
		for iRow := outputOffset; iRow < outputOffset+dimOut84; iRow++ {
			if c < len(matrixRows[iRow]) {
				coeff := matrixRows[iRow][c]
				copy(matrix[offset*32:], mulTableLow[coeff][:])
				copy(matrix[offset*32+16:], mulTableHigh[coeff][:])
			} else {
				// coefficients not used for this input shard (so null out)
				copy(matrix[offset*32:], zeroCoeff[:])
				copy(matrix[offset*32+16:], zeroCoeff[:])
			}
			offset += dimIn84
			if offset >= dimIn84*dimOut84 {
				offset -= dimIn84*dimOut84 - 1
			}
		}
	}
}

func (r reedSolomon) codeSomeShardsAvx512(matrixRows, inputs, outputs [][]byte, outputCount, byteCount int) {

	if r.ParityShards == 4 {
		for inputRow := 0; inputRow < len(inputs); inputRow += dimIn84 {

			galMulAVX512Parallel84(inputs, outputs, matrixRows, inputRow, 0)
		}
	} else if r.DataShards == 8 && r.ParityShards == 8 {

		galMulAVX512Parallel84(inputs, outputs, matrixRows, 0, 0)
		galMulAVX512Parallel84(inputs, outputs, matrixRows, 0, 4)

	} else if r.DataShards == 24 && r.ParityShards == 8 {

		galMulAVX512Parallel84(inputs, outputs, matrixRows, 0, 0)
		galMulAVX512Parallel84(inputs, outputs, matrixRows, 0, 4)

		galMulAVX512Parallel84(inputs, outputs, matrixRows, 8, 0)
		galMulAVX512Parallel84(inputs, outputs, matrixRows, 8, 4)

		galMulAVX512Parallel84(inputs, outputs, matrixRows, 16, 0) 
		galMulAVX512Parallel84(inputs, outputs, matrixRows, 16, 4)

	} else {
		fmt.Println("*** Falling back to non-AVX512 code")
		for c := 0; c < r.DataShards; c++ {
			in := inputs[c]
			for iRow := 0; iRow < outputCount; iRow++ {
				if c == 0 {
					galMulSlice(matrixRows[iRow][c], in, outputs[iRow], r.o)
				} else {
					galMulSliceXor(matrixRows[iRow][c], in, outputs[iRow], r.o)
				}
			}
		}

	}
}
