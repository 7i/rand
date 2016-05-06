package rand

import (
	"testing"
)

var r ComplexRNG

func BenchmarkComplex128(b *testing.B) {
	r = NewComplexRNG(0)

	b.SetBytes(16)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = r.Complex128()

	}
}

func BenchmarkComplex128Go(b *testing.B) {
	r = NewComplexRNG(0)

	b.SetBytes(16)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = r.Complex128Go()
	}
}

func BenchmarkComplexRand(b *testing.B) {
	r = NewComplexRNG(0)

	b.SetBytes(16)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = r.ComplexRand()
	}
}
