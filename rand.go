// Package rand implements the Borland C/C++ pseudo-random number generator
// algorithm [1] to generate random Complex128 numbers in the range (-2,-2i) to (2,2i).
//
//     [1]: https://en.wikipedia.org/wiki/Linear_congruential_generator#Parameters_in_common_use
package rand

import (
	"crypto/rand"
	"fmt"
	"unsafe"

	"github.com/klauspost/cpuid"
)

const (
	// Must be dividable by 16
	complexBufSize = 8192
)

// Function GetSeed returns a 64-bit NIST SP800-90B & C compliant random value from a call to RDSEED.
// If RDSEED is not available or not able to generate a random number in 1024 tries then crypto/rand Read
// is used to create the seed.
// If crypto/rand Read fails then seed is set to 1.
func GetSeed() (a int64) {
	if cpuid.CPU.Rdseed() {
		a, fail := getRdSeed()
		if fail == false {
			return a
		}
	}

	buf := make([]byte, 8)
	_, err := rand.Read(buf)
	if err != nil {
		return 1
	}
	var tmp [8]byte
	for i := range tmp {
		tmp[i] = buf[i]
	}
	return *(*int64)(unsafe.Pointer(&tmp))
}

type ComplexRNG struct {
	buffer  []complex128
	seedbuf []uint32
	seed    int64
	index   uint64
	cpu     int
}

// Function NewComplexRnd returns a new ComplexRNG with the seed set to seed.
// If seed is set to 0 NewComplexRNG will use GetSeed to set seed.
func NewComplexRNG(seed int64) (r ComplexRNG) {
	if seed == 0 {
		r.seed = GetSeed()
	} else {
		r.seed = seed
	}

	tmp1 := make([]byte, complexBufSize*16+32)
	r.buffer = complex128Align32(tmp1) // now of size complexBufSize*16

	seedoffsets := []uint32{0x19b3d997, 0x4ef8197f, 0x68ad182b, 0x851d09a3, 0xa7978b93, 0xcc98d6a7, 0xe17ee303, 0xe2eb7a8d,
		0x50261a5f, 0xf767fe9d, 0xd40b121b, 0x257e5c67, 0x5baf497d, 0xb7439117, 0xfcf9b519, 0x4a22ef33,
		0x98c7dfa5, 0x122e3903, 0x9615d3bb, 0xd5ee709b, 0x3a0fca47, 0xa1f1982d, 0xa0e1907f, 0x29402f9,
		0x6ebcfae1, 0x5686a977, 0x29c8877, 0xb997f0e3, 0xc6be719d, 0xc2dfb8cd, 0xaaab3309, 0x144c8791,
	}

	tmp2 := make([]byte, 192+32)
	// Function uint32Align32 will remove 32 bytes as part of fixing alignment
	r.seedbuf = uint32Align32(tmp2) // now of size 192 = 6 YMM registers.

	// 32 uniq 32bit seeds to be used in the Borland C/C++ LCG algoritm
	for i, v := range seedoffsets {
		r.seedbuf[i] = uint32(r.seed)*v + 1
	}

	// 8 32bit ones to be used as the increment number in the Borland C/C++ LCG algoritm
	for i := 32; i < 40; i++ {
		r.seedbuf[i] = 1
	}

	// 8 32bit magic numbers multiplier from the Borland C/C++ LCG algoritm
	for i := 40; i < 48; i++ {
		r.seedbuf[i] = 0x15A4E35
	}

	if cpuid.CPU.AVX2() {
		r.cpu = 0
	} else if cpuid.CPU.AVX() {
		r.cpu = 1
	} else {
		r.cpu = 2
	}

	switch {
	case r.cpu == 0:
		fillavx2(r.buffer, r.seedbuf)
	case r.cpu == 1:
		fillavx(r.buffer, r.seedbuf)
	default:
		for i := range r.buffer {
			r.buffer[i] = r.Complex128Go()
		}
	}
	return
}

// Complex128Go returns a pseudo-random complex128 where the imag and real part is in the range -2 to 2.
// This method is NOT Thread Safe, initiate one ComplexRNG per goroutine.
func (rng *ComplexRNG) Complex128Go() complex128 {
	// multiplier: a = 6364136223846793005
	// increment:  c = 1
	seed2 := 6364136223846793005*rng.seed + 1
	rng.seed = 6364136223846793005*seed2 + 1
	a := float64(rng.seed) / (1 << 62)
	b := float64(seed2) / (1 << 62)
	return complex(a, b)
}

// Method Complex128 returns a random complex128 in the range (-2 - 2, -2 - 2).
// This method is NOT Thread Safe, initiate one ComplexRNG per goroutine.
func (rng *ComplexRNG) Complex128() (c complex128) {
	// Intel Static Branch Prediction: A forward branch defaults to not taken and a backward branch defaults to taken.
	if rng.index < complexBufSize {
		rng.index++
		return rng.buffer[rng.index-1]
	}
	switch {
	case rng.cpu == 0:
		fillavx2(rng.buffer, rng.seedbuf) // will update seed and all elements in buffer
	case rng.cpu == 1:
		fillavx(rng.buffer, rng.seedbuf)
	default:
		for i := range rng.buffer {
			rng.buffer[i] = rng.Complex128Go()
		}
	}
	rng.index = 1
	return rng.buffer[0]
}

// Function AddUint64 returns the new and old value after adding delta, this function is executed atomicly.
func AddUint64(addr *uint64, delta uint64) (new, old uint64)

func fillavx(buf []complex128, seedbuf []uint32)

func fillavx2(buf []complex128, seedbuf []uint32)

// ComplexRand returns a pseudo-random complex128 where the imag and real part is in the range -2 to 2.
// The random values are evenly distributed between all possible floats in the specified range, this makes
// it very lightly to get a very small number very close to 0 as the densety of valid floats are much denser near 0.
func ComplexRand(x, y int64) complex128

func Abs(x float64) float64

// Function getRdSeed tries to get a random number via RDSEED instruction in the CPU.
func getRdSeed() (a int64, fail bool)

// Function align32 takes a slice and returns a slice that is 32 bytes smaller and that is aligned by 32.
func uint32Align32(buf []byte) []uint32

func complex128Align32(buf []byte) []complex128
