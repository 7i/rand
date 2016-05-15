// Package rand implements the Borland C/C++ pseudo-random number generator
// algorithm [1] to generate random Complex128 numbers in the range (-2,-2i) to (2,2i).
//
//     [1]: https://en.wikipedia.org/wiki/Linear_congruential_generator#Parameters_in_common_use
package rand

import (
	"crypto/rand"
	"sync/atomic"
	"unsafe"

	"github.com/klauspost/cpuid"
)

// Function GetSeed returns a 64-bit NIST SP800-90B & C compliant random value from a call to RDSEED.
// If RDSEED is not available or not able to generate a random number in 1024 tries then crypto/rand Read
// is used to create the seed.
func GetSeed() (a int64, err error) {
	if cpuid.CPU.Rdseed() {
		a, fail := getRdSeed()
		if fail == false {
			return a, nil
		}
	}

	buf := make([]byte, 8)
	len, err := rand.Read(buf)
	if err != nil || len != 8 {
		return 0, err
	}

	// Convert a Slice to a int64
	return **(**int64)(unsafe.Pointer(&buf)), nil
}

type ComplexRNG struct {
	seed uint64
}

type ComplexRNGts struct {
	seed uint64
	next uint64
}

// Function NewComplexRndts returns a new ComplexRNG with the seed set to seed.
// If seed is set to 0 NewComplexRNGts will use GetSeed to set seed.
// All methods on NewComplexRndts have sacrificed speed for thread safety.
// Equivalent methods on NewComplexRNG are about 5X faster.
func NewComplexRNGts(seed int64) (r ComplexRNGts, err error) {
	if seed == 0 {
		s, err := GetSeed()
		if err != nil {
			return r, err
		}
		r.seed = uint64(s)
		r.next = 6364136223846793005*r.seed + 1
	} else {
		r.seed = uint64(seed)
		r.next = 6364136223846793005*r.seed + 1
	}
	return
}

// Function NewComplexRnd returns a new ComplexRNG with the seed set to seed.
// If seed is set to 0 NewComplexRNG will use GetSeed to set seed.
// Methods on NewComplexRndThis are NOT Thread Safe, initiate one ComplexRNG per goroutine.
func NewComplexRNG(seed int64) (r ComplexRNG, err error) {
	if seed == 0 {
		s, err := GetSeed()
		if err != nil {
			return r, err
		}
		r.seed = uint64(s)
	} else {
		r.seed = uint64(seed)
	}
	return
}

// Complex128 returns a pseudo-random complex128 where the imag and real part is in the range -2 to 2.
func (rng *ComplexRNG) Complex128() complex128 {
	// multiplier: a = 6364136223846793005
	// increment:  c = 1
	a := 6364136223846793005*rng.seed + 1
	rng.seed = 6364136223846793005*a + 1
	return complex(float64(a)/(1<<62), float64(rng.seed)/(1<<62))
}

// Complex128 returns a pseudo-random complex128 where the imag and real part is in the range -2 to 2.
func (rng *ComplexRNGts) Complex128() complex128 {
	for {
		a := 6364136223846793005*rng.seed + 1 // rng.next and real part of complex
		if rng.next == a {
			b := 6364136223846793005*a + 1 // Next rng.seed and imag part of complex
			if atomic.CompareAndSwapUint64(&rng.next, a, 6364136223846793005*b+1) {
				atomic.StoreUint64(&rng.seed, b)
				return complex(float64(a)/(1<<62), float64(b)/(1<<62))
			}
		}
	}
}

// ComplexRand returns a pseudo-random complex128 where the imag and real part is in the range -2 to 2.
// The random values are evenly distributed between all possible floats in the specified range, this makes
// it very lightly to get a very small number very close to 0 as the density of valid floats are much denser near 0.
// Eg. The probability of getting a real part that is over 1 or lower than -1 is about 0.1% and the probability of
// getting a real part in between 1.0e-150 and -1.0e-150 is about 50%.
func (rng *ComplexRNG) ComplexRand() complex128 {
	a := 6364136223846793005*rng.seed + 1
	rng.seed = 6364136223846793005*a + 1
	b := rng.seed & 0xBFFFFFFFFFFFFFFF
	a = a & 0xBFFFFFFFFFFFFFFF
	return complex(*(*float64)(unsafe.Pointer(&a)), *(*float64)(unsafe.Pointer(&b)))
}

// ComplexRand returns a pseudo-random complex128 where the imag and real part is in the range -2 to 2.
// The random values are evenly distributed between all possible floats in the specified range, this makes
// it very lightly to get a very small number very close to 0 as the density of valid floats are much denser near 0.
// Eg. The probability of getting a real part that is over 1 or lower than -1 is about 0.1% and the probability of
// getting a real part in between 1.0e-150 and -1.0e-150 is about 50%.
func (rng *ComplexRNGts) ComplexRand() complex128 {
	for {
		a := 6364136223846793005*rng.seed + 1 // rng.next and real part of complex
		if rng.next == a {
			b := 6364136223846793005*a + 1 // Next rng.seed and imag part of complex
			c := 6364136223846793005*b + 1 // Next rng.next
			if atomic.CompareAndSwapUint64(&rng.next, a, c) {
				atomic.StoreUint64(&rng.seed, b)
				b = b & 0xBFFFFFFFFFFFFFFF
				a = a & 0xBFFFFFFFFFFFFFFF
				return complex(*(*float64)(unsafe.Pointer(&a)), *(*float64)(unsafe.Pointer(&b)))
			}
		}
	}
}

// Function AddUint64 returns the new and old value after adding delta, this function is executed atomically.
func AddUint64(addr *uint64, delta uint64) (new, old uint64)

func Abs(x float64) float64

// Function getRdSeed tries to get a random number via RDSEED instruction in the CPU.
func getRdSeed() (a int64, fail bool)
