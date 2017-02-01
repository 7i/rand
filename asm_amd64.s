#include "textflag.h"

//; func Abs(x float64) float64
TEXT ·Abs(SB),NOSPLIT,$0
	MOVQ         $(1<<63), BX
	MOVQ         BX, X0 
	MOVSD        x+0(FP), X1
	ANDNPD       X1, X0
	MOVSD        X0, ret+8(FP)
	RET


//; func ComplexRand(x, y int64) complex128 // No longer used, only kept for historical reasons 
TEXT ·complexRand(SB),NOSPLIT,$0
	MOVQ         a+0(FP), SI       //; pointer to Random float1
	MOVQ         0(SI), AX
	MOVQ         $0x5851f42d4c957f2d, BX
	MOVQ         $0xBFFFFFFFFFFFFFFF, DI
	MULQ         BX
	INCQ         AX
	MOVQ         AX, CX
	ANDQ         DI, CX
	MULQ         BX
	INCQ         AX
	MOVQ         AX, 0(SI)         //; Update seed
	ANDQ         DI, AX
	MOVQ         CX, a+8(FP)       //; Complex return part 1
	MOVQ         AX, a+16(FP)      //; Complex return part 2
	RET


//; func GetRdSeed() (a int64)
TEXT ·getRdSeed(SB),NOSPLIT,$0
	XORQ         CX, CX

try:
	INCW         CX
	CMPW         CX, $1024
	JG           ret1              //; Return false = 1 after 1024 failed attempts

	// Unsupported instruction RDSEEDQ SI 
	BYTE $0x48; BYTE $0x0f; BYTE $0xc7; BYTE $0xfE //; Try to get 64 bit random number

	JNC          try               //; Try again if we did not get a valid random number
	MOVQ         SI, a+0(FP)
	RET

ret1:
	MOVB         $1, a+8(FP)
	RET


TEXT ·AddUint64(SB),NOSPLIT,$0-24
	MOVQ         addr+0(FP), BP    //; Pointer to int64
	MOVQ         delta+8(FP), AX   //; Delta
	MOVQ         AX, CX            //; Delta
	LOCK                           //; Set XADDQ to execute atomicly 
	XADDQ        AX, 0(BP)         //; Update the int64 by adding Delta and move the old value to AX
	MOVQ         AX, new+24(FP)    //; Set second return value to the old int64 value    
	ADDQ         AX, CX            //; Add old and delta 
	MOVQ         CX, new+16(FP)    //; Set first return value to the new int64 value 
	RET

// No longer used, only kept for historical reasons 
TEXT ·complex128Align32(SB),NOSPLIT,$0
	MOVQ         addr+0(FP), SI    //; Pointer to buf
	MOVQ         a+8(FP), AX       //; Length of buf
	//;          a+16(FP)          //; Capacity, not used
	ADDQ         $32, SI
	ANDQ         $-32, SI          //; Align 32
	SUBQ         $32, AX           //; Length - 32
	SHRQ         $4, AX            //; Divide by 16 to get length in complex128 instead of bytes
	MOVQ         SI, new+24(FP)    //; Pointer to buffer
	MOVQ         AX, new+32(FP)    //; Size of new slice
	MOVQ         AX, new+40(FP)    //; Capacity of new slice
	RET

// No longer used, only kept for historical reasons 
TEXT ·uint32Align32(SB),NOSPLIT,$0
	MOVQ         addr+0(FP), SI    //; Pointer to buf
	MOVQ         a+8(FP), AX       //; Length of buf
	//           a+16(FP)          //; Capacity, not used
	ADDQ         $32, SI
	ANDQ         $-32, SI          //; Align 32
	SUBQ         $32, AX           //; Length - 32
	SHRQ         $2, AX            //; Divide by 4 to get length in uint32 instead of bytes
	MOVQ         SI, new+24(FP)    //; Pointer to buffer
	MOVQ         AX, new+32(FP)    //; Size of new slice
	MOVQ         AX, new+40(FP)    //; Capacity of new slice
	RET


//; func fillavx2(buf []complex128, seedbuf []uint32) // No longer used, only kept for historical reasons 
TEXT ·fillavx2(SB),NOSPLIT,$0
///;### For AVX2 use 
	MOVQ         a+0(FP), SI       //; Pointer to buffer
	MOVQ         a+8(FP), AX       //; Length of buffer in complex128
	//;          a+16(FP)          //; Capacity of buffer, not used
	MOVQ         a+24(FP), CX      //; Pointer to seedbuf
	//;          a+32(FP)          //; Length of seedbuff not used
	//;          a+40(FP)          //; Capacity of seedbuff not used
 	XORQ         BX, BX

	VMOVDQA         (CX), Y1       //; Move 256bits in to Y4 containing 8 32bit seed numbers
	VMOVDQA       32(CX), Y2       //; Move 256bits in to Y4 containing 8 32bit seed numbers
	VMOVDQA       64(CX), Y3       //; Move 256bits in to Y4 containing 8 32bit seed numbers
	VMOVDQA       96(CX), Y4       //; Move 256bits in to Y4 containing 8 32bit seed numbers

	VMOVDQA      128(CX), Y13      //; Move 256bits in to Y13 containing 8 32bit increment numbers
	VMOVDQA      160(CX), Y14      //; Move 256bits in to Y14 containing 8 32bit multiplier numbers

///### Unsuported instructions in Go
	BYTE $0xC4; BYTE $0x63; BYTE $0x7D; BYTE $0x19; BYTE $0xE8; BYTE $0x01  //; VEXTRACTF128 $1, Y13, X0    //; Copy high 128 bits of Y13 in to X0 for use in VDIVPD

	VPSLLD       $30, X0, X0       //; X0 now contains 4 int32 with the value (1<<30)

	BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xC0                          //; VCVTDQ2PD    X0, Y0         //; Y0 now contains 4 float64 with the value (1<<30)

mainLoopAVX2:
	BYTE $0xC4; BYTE $0xC2; BYTE $0x75; BYTE $0x40; BYTE $0xCE              //; VPMULLD      Y14, Y1, Y1
	BYTE $0xC4; BYTE $0xC2; BYTE $0x6D; BYTE $0x40; BYTE $0xD6              //; VPMULLD      Y14, Y2, Y2
	BYTE $0xC4; BYTE $0xC2; BYTE $0x65; BYTE $0x40; BYTE $0xDE              //; VPMULLD      Y14, Y3, Y3
	BYTE $0xC4; BYTE $0xC2; BYTE $0x5D; BYTE $0x40; BYTE $0xE6              //; VPMULLD      Y14, Y4, Y4

	VPADDD       Y14, Y1, Y1
	VPADDD       Y14, Y2, Y2
	VPADDD       Y14, Y3, Y3
	VPADDD       Y14, Y4, Y4

	VMOVDQA      Y1, Y5
	VMOVDQA      Y2, Y6
	VMOVDQA      Y3, Y7
	VMOVDQA      Y4, Y8

	BYTE $0xC4; BYTE $0xC3; BYTE $0x7D; BYTE $0x19; BYTE $0xE9; BYTE $0x01  //; VEXTRACTF128 $1, Y5, X9     //; Copy high 128 bit to X9
	BYTE $0xC4; BYTE $0xC3; BYTE $0x7D; BYTE $0x19; BYTE $0xF2; BYTE $0x01  //; VEXTRACTF128 $1, Y6, X10    //; Copy high 128 bit to X10
	BYTE $0xC4; BYTE $0xC3; BYTE $0x7D; BYTE $0x19; BYTE $0xFB; BYTE $0x01  //; VEXTRACTF128 $1, Y7, X11    //; Copy high 128 bit to X11
	BYTE $0xC4; BYTE $0x43; BYTE $0x7D; BYTE $0x19; BYTE $0xC4; BYTE $0x01  //; VEXTRACTF128 $1, Y8, X12    //; Copy high 128 bit to X12

	BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xED                          //; VCVTDQ2PD    X5,  Y5        //; Convert 4 of the lower signed seed values to float64
	BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xF6                          //; VCVTDQ2PD    X6,  Y6        //; Convert 4 of the lower signed seed values to float64
	BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xFF                          //; VCVTDQ2PD    X7,  Y7        //; Convert 4 of the lower signed seed values to float64
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xC0              //; VCVTDQ2PD    X8,  Y8        //; Convert 4 of the lower signed seed values to float64
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xC9              //; VCVTDQ2PD    X9,  Y9        //; Convert 4 of the lower signed seed values to float64
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xD2              //; VCVTDQ2PD    X10, Y10       //; Convert 4 of the lower signed seed values to float64
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xDB              //; VCVTDQ2PD    X11, Y11       //; Convert 4 of the lower signed seed values to float64
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xE4              //; VCVTDQ2PD    X12, Y12       //; Convert 4 of the lower signed seed values to float64

	BYTE $0xC5; BYTE $0xD5; BYTE $0x5E; BYTE $0xE8                          //; VDIVPD       Y0, Y5,  Y5    //; Divide the float64 with (1<<30) to get it in to the range 2 - -2
	BYTE $0xC5; BYTE $0xCD; BYTE $0x5E; BYTE $0xF0                          //; VDIVPD       Y0, Y6,  Y6    //; Divide the float64 with (1<<30) to get it in to the range 2 - -2
	BYTE $0xC5; BYTE $0xC5; BYTE $0x5E; BYTE $0xF8                          //; VDIVPD       Y0, Y7,  Y7    //; Divide the float64 with (1<<30) to get it in to the range 2 - -2
	BYTE $0xC5; BYTE $0x3D; BYTE $0x5E; BYTE $0xC0                          //; VDIVPD       Y0, Y8,  Y8    //; Divide the float64 with (1<<30) to get it in to the range 2 - -2
	BYTE $0xC5; BYTE $0x35; BYTE $0x5E; BYTE $0xC8                          //; VDIVPD       Y0, Y9,  Y9    //; Divide the float64 with (1<<30) to get it in to the range 2 - -2
	BYTE $0xC5; BYTE $0x2D; BYTE $0x5E; BYTE $0xD0                          //; VDIVPD       Y0, Y10, Y10   //; Divide the float64 with (1<<30) to get it in to the range 2 - -2
	BYTE $0xC5; BYTE $0x25; BYTE $0x5E; BYTE $0xD8                          //; VDIVPD       Y0, Y11, Y11   //; Divide the float64 with (1<<30) to get it in to the range 2 - -2
	BYTE $0xC5; BYTE $0x1D; BYTE $0x5E; BYTE $0xE0                          //; VDIVPD       Y0, Y12, Y12   //; Divide the float64 with (1<<30) to get it in to the range 2 - -2

	VMOVDQA      Y5,     (SI)
	VMOVDQA      Y6,   32(SI)
	VMOVDQA      Y7,   64(SI)
	VMOVDQA      Y8,   96(SI)
	VMOVDQA      Y9,  128(SI)
	VMOVDQA      Y10, 160(SI)
	VMOVDQA      Y11, 192(SI)
	VMOVDQA      Y12, 224(SI)

	ADDQ         $256, SI          //; 16 * complex128 = 256 bytes
	ADDQ         $16, BX
	CMPQ         BX, AX
	JL           mainLoopAVX2      //; If Si >= buflen return

	VMOVDQA		 Y1,   (CX)        //; Save seed numbers
	VMOVDQA		 Y2, 32(CX)        //; Save seed numbers
	VMOVDQA		 Y3, 64(CX)        //; Save seed numbers
	VMOVDQA		 Y4, 96(CX)        //; Save seed numbers

	RET
///;### End AVX2 use


//; func fillavx(buf []complex128, seedbuf []uint32) // No longer used, only kept for historical reasons 
TEXT ·fillavx(SB),NOSPLIT,$0
///;### For AVX use
	MOVQ         a+0(FP), SI       //; Pointer to buffer
	MOVQ         a+8(FP), AX       //; Length of buffer in complex128
	//;          a+16(FP)          //; Capacity of buffer, not used
	MOVQ         a+24(FP), CX      //; Pointer to seedbuf
	//;          a+32(FP)          //; Length of seedbuff not used
	//;          a+40(FP)          //; Capacity of seedbuff not used
 	XORQ         BX, BX

	VMOVDQA         (CX), X0       //; Move 128bits in to X0 containing 4 32bit seed numbers
	VMOVDQA       16(CX), X1       //; Move 128bits in to X1 containing 4 32bit seed numbers
	VMOVDQA       32(CX), X2       //; Move 128bits in to X2 containing 4 32bit seed numbers
	VMOVDQA       48(CX), X3       //; Move 128bits in to X3 containing 4 32bit seed numbers
	VMOVDQA       64(CX), X4       //; Move 128bits in to X4 containing 4 32bit seed numbers
	VMOVDQA       80(CX), X5       //; Move 128bits in to X5 containing 4 32bit seed numbers
	VMOVDQA       96(CX), X6       //; Move 128bits in to X6 containing 4 32bit seed numbers
	VMOVDQA      112(CX), X7       //; Move 128bits in to X7 containing 4 32bit seed numbers
	VMOVDQA      128(CX), X15      //; Move 128bits in to X15 containing 4 32bit increment numbers
	VMOVDQA      160(CX), X14      //; Move 128bits in to X14 containing 4 32bit multiplier numbers

	VMOVDQA      X15, X13
	VPSLLD       $30, X13, X13
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xED;  //; VCVTDQ2PD    X13, Y13
	//; Y13 now contains 4 float64 with the value (1<<30), later used with VDIVPD

mainLoopAVX:
	BYTE $0xC4; BYTE $0xC2; BYTE $0x79; BYTE $0x40; BYTE $0xC6              //; VPMULLD      X14, X0, X0
	BYTE $0xC4; BYTE $0xC2; BYTE $0x71; BYTE $0x40; BYTE $0xCE              //; VPMULLD      X14, X1, X1
	BYTE $0xC4; BYTE $0xC2; BYTE $0x69; BYTE $0x40; BYTE $0xD6              //; VPMULLD      X14, X2, X2
	BYTE $0xC4; BYTE $0xC2; BYTE $0x61; BYTE $0x40; BYTE $0xDE              //; VPMULLD      X14, X3, X3
	BYTE $0xC4; BYTE $0xC2; BYTE $0x59; BYTE $0x40; BYTE $0xE6              //; VPMULLD      X14, X4, X4
	BYTE $0xC4; BYTE $0xC2; BYTE $0x51; BYTE $0x40; BYTE $0xEE              //; VPMULLD      X14, X5, X5
	BYTE $0xC4; BYTE $0xC2; BYTE $0x49; BYTE $0x40; BYTE $0xF6              //; VPMULLD      X14, X6, X6
	BYTE $0xC4; BYTE $0xC2; BYTE $0x41; BYTE $0x40; BYTE $0xFE              //; VPMULLD      X14, X7, X7

	VPADDD       X15, X0, X0
	VPADDD       X15, X1, X1
	VPADDD       X15, X2, X2
	VPADDD       X15, X3, X3
	VPADDD       X15, X4, X4
	VPADDD       X15, X5, X5
	VPADDD       X15, X6, X6
	VPADDD       X15, X7, X7

	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xC0                          //; VCVTDQ2PD    X0, Y8
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xC9                          //; VCVTDQ2PD    X1, Y9
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xD2                          //; VCVTDQ2PD    X2, Y10
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xDB                          //; VCVTDQ2PD    X3, Y11

	BYTE $0xC4; BYTE $0x41; BYTE $0x3D; BYTE $0x5E; BYTE $0xC5              //; VDIVPD       Y13, Y8, Y8
	BYTE $0xC4; BYTE $0x41; BYTE $0x35; BYTE $0x5E; BYTE $0xCD              //; VDIVPD       Y13, Y9, Y9
	BYTE $0xC4; BYTE $0x41; BYTE $0x2D; BYTE $0x5E; BYTE $0xD5              //; VDIVPD       Y13, Y10, Y10
	BYTE $0xC4; BYTE $0x41; BYTE $0x25; BYTE $0x5E; BYTE $0xDD              //; VDIVPD       Y13, Y11, Y11

	VMOVDQA      Y8,    (SI)
	VMOVDQA      Y9,  32(SI)
	VMOVDQA      Y10, 64(SI)
	VMOVDQA      Y11, 96(SI)

	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xC4                          //; VCVTDQ2PD    X4, Y8
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xCD                          //; VCVTDQ2PD    X5, Y9
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xD6                          //; VCVTDQ2PD    X6, Y10
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xDF                          //; VCVTDQ2PD    X7, Y11

	BYTE $0xC4; BYTE $0x41; BYTE $0x3D; BYTE $0x5E; BYTE $0xC5              //; VDIVPD       Y13, Y8, Y8
	BYTE $0xC4; BYTE $0x41; BYTE $0x35; BYTE $0x5E; BYTE $0xCD              //; VDIVPD       Y13, Y9, Y9
	BYTE $0xC4; BYTE $0x41; BYTE $0x2D; BYTE $0x5E; BYTE $0xD5              //; VDIVPD       Y13, Y10, Y10
	BYTE $0xC4; BYTE $0x41; BYTE $0x25; BYTE $0x5E; BYTE $0xDD              //; VDIVPD       Y13, Y11, Y11

	VMOVDQA      Y8,  128(SI)
	VMOVDQA      Y9,  160(SI)
	VMOVDQA      Y10, 192(SI)
	VMOVDQA      Y11, 224(SI)

	ADDQ         $256, SI          //; 16 * complex128 = 256 bytes
	ADDQ         $16, BX
	CMPQ         BX, AX
	JL           mainLoopAVX       //; If Si >= buflen return

	VMOVDQA      X0,    (CX)       //; Move 128bits in to X0 containing 4 32bit seed numbers
	VMOVDQA      X1,  16(CX)       //; Move 128bits in to X1 containing 4 32bit seed numbers
	VMOVDQA      X2,  32(CX)       //; Move 128bits in to X2 containing 4 32bit seed numbers
	VMOVDQA      X3,  48(CX)       //; Move 128bits in to X3 containing 4 32bit seed numbers
	VMOVDQA      X4,  64(CX)       //; Move 128bits in to X4 containing 4 32bit seed numbers
	VMOVDQA      X5,  80(CX)       //; Move 128bits in to X5 containing 4 32bit seed numbers
	VMOVDQA      X6,  96(CX)       //; Move 128bits in to X6 containing 4 32bit seed numbers
	VMOVDQA      X7, 112(CX)       //; Move 128bits in to X7 containing 4 32bit seed numbers

	RET
///;### End AVX use	

