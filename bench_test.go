package rand

import (
	"fmt"
	"sort"
	"testing"
)

func TestComplex128(t *testing.T)  { testComplexRNG("Complex128") }
func TestComplexRand(t *testing.T) { testComplexRNG("ComplexRand") }

func TestComplex128ts(t *testing.T)  { testComplexRNGts("Complex128") }
func TestComplexRandts(t *testing.T) { testComplexRNGts("ComplexRand") }

func testComplexRNG(method string) {
	c := make(chan float64)
	threads := sort.Float64Slice(make([]float64, 200000))
	sequential := sort.Float64Slice(make([]float64, 200000))

	r, _ := NewComplexRNG(1)
	for i := 0; i < 1000; i++ {
		go func() {
			for j := 0; j < 100; j++ {
				var a complex128
				switch method {
				case "Complex128":
					a = r.Complex128()
				case "ComplexRand":
					a = r.ComplexRand()
				}
				c <- real(a)
				c <- imag(a)
			}
		}()
	}

	for i := 0; i < 200000; i++ {
		threads[i] = <-c
	}

	threads.Sort()

	s, _ := NewComplexRNG(1)

	switch method {
	case "Complex128":
		for i := 0; i < 200000; i += 2 {
			a := s.Complex128()
			sequential[i] = real(a)
			sequential[i+1] = imag(a)
		}
	case "ComplexRand":
		for i := 0; i < 200000; i += 2 {
			a := s.ComplexRand()
			sequential[i] = real(a)
			sequential[i+1] = imag(a)
		}
	}

	sequential.Sort()

	fail := false

	for i := range threads {
		if threads[i] != sequential[i] {
			fail = true
			break
		}
	}
	if fail {
		fmt.Println("Thread-safety ComplexRNG." + method + "() - Fail (Expected)")
	} else {
		fmt.Println("Thread-safety ComplexRNG." + method + "() - OK")
	}
}

func testComplexRNGts(method string) {
	c := make(chan float64)
	threads := sort.Float64Slice(make([]float64, 200000))
	sequential := sort.Float64Slice(make([]float64, 200000))

	r, _ := NewComplexRNGts(1)
	for i := 0; i < 1000; i++ {
		go func() {
			for j := 0; j < 100; j++ {
				var a complex128
				switch method {
				case "Complex128":
					a = r.Complex128()
				case "ComplexRand":
					a = r.ComplexRand()
				}
				c <- real(a)
				c <- imag(a)
			}
		}()
	}

	for i := 0; i < 200000; i++ {
		threads[i] = <-c
	}

	threads.Sort()

	s, _ := NewComplexRNGts(1)

	switch method {
	case "Complex128":
		for i := 0; i < 200000; i += 2 {
			a := s.Complex128()
			sequential[i] = real(a)
			sequential[i+1] = imag(a)
		}
	case "ComplexRand":
		for i := 0; i < 200000; i += 2 {
			a := s.ComplexRand()
			sequential[i] = real(a)
			sequential[i+1] = imag(a)
		}
	}

	sequential.Sort()

	fail := false

	for i := range threads {
		if threads[i] != sequential[i] {
			fail = true
			break
		}
	}
	if fail {
		fmt.Println("Thread-safety ComplexRNGts." + method + "() - Fail")
	} else {
		fmt.Println("Thread-safety ComplexRNGts." + method + "() - OK")
	}
}

func BenchmarkComplex128(b *testing.B) {
	r, _ := NewComplexRNG(1)

	b.SetBytes(16)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = r.Complex128()
	}
}

func BenchmarkComplex128ts(b *testing.B) {
	r, _ := NewComplexRNGts(1)

	b.SetBytes(16)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = r.Complex128()
	}
}

func BenchmarkGetSeed(b *testing.B) {
	b.SetBytes(8)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = GetSeed()
	}
}

func BenchmarkComplexRand(b *testing.B) {
	r, _ := NewComplexRNG(1)

	b.SetBytes(16)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = r.ComplexRand()
	}
}

func BenchmarkComplexRandts(b *testing.B) {
	r, _ := NewComplexRNGts(1)

	b.SetBytes(16)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = r.ComplexRand()
	}
}
