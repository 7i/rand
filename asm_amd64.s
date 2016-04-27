#include "textflag.h"

//; func Abs(x float64) float64
TEXT ·Abs(SB),NOSPLIT,$0
    MOVQ   $(1<<63), BX
    MOVQ   BX, X0 
    MOVSD  x+0(FP), X1
    ANDNPD X1, X0
    MOVSD  X0, ret+8(FP)
    RET


//; func rnd(x, y int64) complex128
TEXT ·ComplexRand2(SB),NOSPLIT,$0
	MOVQ a+0(FP), SI   //; random float1
	MOVQ a+8(FP), CX   //; random float2
	MOVQ $0xBFFFFFFFFFFFFFFF, DX
    ANDQ DX, SI
    ANDQ DX, CX
	MOVQ SI, a+16(FP)  //; complex return part 1
	MOVQ CX, a+24(FP)  //; complex return part 2
	RET


//; func GetRdSeed() (a int64)
TEXT ·getRdSeed(SB),NOSPLIT,$0
	XORQ   CX, CX

try:
	INCW    CX
	CMPW    CX, $1024
	JG      ret1        //; Return false = 1 after 1024 failed attempts 

	// Unsupported instruction RDSEEDQ SI 
	BYTE $0x48; BYTE $0x0f; BYTE $0xc7; BYTE $0xfE //; Try to get 64 bit random number

	JNC     try         //; Try again if we did not get a valid random number
	MOVQ    SI, a+0(FP)
	RET

ret1:
	MOVB    $1, a+8(FP)
	RET

TEXT ·AddUint64(SB),NOSPLIT,$0-24
	MOVQ	addr+0(FP), BP     //; Pointer to int64
	MOVQ	delta+8(FP), AX    //; Delta
	MOVQ	AX, CX             //; Delta
	LOCK                       //; Set XADDQ to execute atomicly 
	XADDQ	AX, 0(BP)          //; Update the int64 by adding Delta and move the old value to AX
	MOVQ    AX, new+24(FP)     //; Set second return value to the old int64 value    
	ADDQ	AX, CX             //; Add old and delta 
	MOVQ	CX, new+16(FP)     //; Set first return value to the new int64 value 
	RET

TEXT ·complex128Align32(SB),NOSPLIT,$0 
	MOVQ	addr+0(FP), SI     //; Pointer to buf
	MOVQ 	a+8(FP), AX		   //; Length of buf
	//      a+16(FP)           //; Capacity, not used
	ADDQ	$32, SI
	ANDQ	$-32, SI		   //; Align 32
	SUBQ	$32, AX			   //; Length - 32
	SHRQ	$4, AX			   //; Divide by 16 to get length in complex128 instead of bytes
	MOVQ	SI, new+24(FP)	   //; Pointer to buffer
	MOVQ	AX, new+32(FP)     //; Size of new slice
	MOVQ	AX, new+40(FP)     //; capacity of new slice
	RET

TEXT ·uint32Align32(SB),NOSPLIT,$0
	MOVQ	addr+0(FP), SI     //; Pointer to buf
	MOVQ 	a+8(FP), AX		   //; Length of buf
	//      a+16(FP)           //; Capacity, not used
	ADDQ	$32, SI
	ANDQ	$~31, SI		   //; Align 32
	SUBQ	$32, AX			   //; Length - 32
	SHRQ	$2, AX			   //; Divide by 4 to get length in uint32 instead of bytes
	MOVQ	SI, new+24(FP)	   //; Pointer to buffer
	MOVQ	AX, new+32(FP)     //; Size of new slice
	MOVQ	AX, new+40(FP)     //; capacity of new slice
	RET

//; func fillavx2(buf []complex128, seedbuf []uint32)
TEXT ·fillavx2(SB),NOSPLIT,$0
	MOVQ a+0(FP), SI    //; pointer to buffer
	MOVQ a+8(FP), AX    //; length of buffer in complex128
	//;  a+16(FP)       //; capacity of buffer, not used
	MOVQ a+24(FP), CX   //; pointer to seedbuf
	//;  a+32(FP)       //; length of seedbuff not used
	//;  a+40(FP)       //; capacity of seedbuff not used
 	MOVQ $256, BX

///;### For AVX2 use 
	VMOVDQA		   (CX), Y1		//; move 256bits in to Y4 containing 8 32bit seed numbers
	VMOVDQA		 32(CX), Y2		//; move 256bits in to Y4 containing 8 32bit seed numbers
	VMOVDQA		 64(CX), Y3		//; move 256bits in to Y4 containing 8 32bit seed numbers
	VMOVDQA		 96(CX), Y4		//; move 256bits in to Y4 containing 8 32bit seed numbers

	VMOVDQA 	128(CX), Y13  	//; move 256bits in to Y13 containing 8 32bit increment numbers
	VMOVDQA 	160(CX), Y14  	//; move 256bits in to Y14 containing 8 32bit multiplier numbers

///### Start of Go unsuported section
	BYTE $0xC4; BYTE $0x63; BYTE $0x7D; BYTE $0x19; BYTE $0xE8; BYTE $0x00; BYTE $0xC5; BYTE $0xF9; 
	BYTE $0x72; BYTE $0xF0; BYTE $0x1E; BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xC0; 
mainLoopAVX2:
	BYTE $0xC4; BYTE $0xC2; BYTE $0x75; BYTE $0x40; BYTE $0xCE; BYTE $0xC4; BYTE $0xC2; BYTE $0x6D; 
	BYTE $0x40; BYTE $0xD6; BYTE $0xC4; BYTE $0xC2; BYTE $0x65; BYTE $0x40; BYTE $0xDE; BYTE $0xC4; 
	BYTE $0xC2; BYTE $0x5D; BYTE $0x40; BYTE $0xE6; BYTE $0xC4; BYTE $0xC1; BYTE $0x75; BYTE $0xFE; 
	BYTE $0xCD; BYTE $0xC4; BYTE $0xC1; BYTE $0x6D; BYTE $0xFE; BYTE $0xD5; BYTE $0xC4; BYTE $0xC1; 
	BYTE $0x65; BYTE $0xFE; BYTE $0xDD; BYTE $0xC4; BYTE $0xC1; BYTE $0x5D; BYTE $0xFE; BYTE $0xE5; 
	BYTE $0xC5; BYTE $0xFD; BYTE $0x6F; BYTE $0xE9; BYTE $0xC5; BYTE $0xFD; BYTE $0x6F; BYTE $0xF2; 
	BYTE $0xC5; BYTE $0xFD; BYTE $0x6F; BYTE $0xFB; BYTE $0xC5; BYTE $0x7D; BYTE $0x6F; BYTE $0xC4; 
	BYTE $0xC4; BYTE $0xC3; BYTE $0x7D; BYTE $0x19; BYTE $0xE9; BYTE $0x01; BYTE $0xC4; BYTE $0xC3; 
	BYTE $0x7D; BYTE $0x19; BYTE $0xF2; BYTE $0x01; BYTE $0xC4; BYTE $0xC3; BYTE $0x7D; BYTE $0x19; 
	BYTE $0xFB; BYTE $0x01; BYTE $0xC4; BYTE $0x43; BYTE $0x7D; BYTE $0x19; BYTE $0xC4; BYTE $0x01; 
	BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xED; BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xF6; 
	BYTE $0xC5; BYTE $0xFE; BYTE $0xE6; BYTE $0xFF; BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; 
	BYTE $0xC0; BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xC9; BYTE $0xC4; BYTE $0x41; 
	BYTE $0x7E; BYTE $0xE6; BYTE $0xD2; BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xDB; 
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xE4; BYTE $0xC5; BYTE $0xD5; BYTE $0x5E; 
	BYTE $0xEF; BYTE $0xC5; BYTE $0xCD; BYTE $0x5E; BYTE $0xF7; BYTE $0xC5; BYTE $0xC5; BYTE $0x5E; 
	BYTE $0xFF; BYTE $0xC5; BYTE $0x3D; BYTE $0x5E; BYTE $0xC7; BYTE $0xC5; BYTE $0x35; BYTE $0x5E; 
	BYTE $0xCF; BYTE $0xC5; BYTE $0x2D; BYTE $0x5E; BYTE $0xD7; BYTE $0xC5; BYTE $0x25; BYTE $0x5E; 
	BYTE $0xDF; BYTE $0xC5; BYTE $0x1D; BYTE $0x5E; BYTE $0xE7;
///### End of Go unsuported section

///### Above blob contains the following:
//#	VEXTRACTF128 $0, Y13, X0 	//; copy low 128 bit to X0 for use in VDIVPD
//#	VPSLLD		 $30, X0, X0	//; X0 now contains 4 int32 with the value (1<<30)
//#	VCVTDQ2PD	 X0, Y0			//; Y0 now contains 4 float64 with the value (1<<30)
//#
//#mainLoopAVX2:
//#	VPMULLD		 Y14, Y1, Y1	
//#	VPMULLD		 Y14, Y2, Y2	
//#	VPMULLD		 Y14, Y3, Y3	
//#	VPMULLD		 Y14, Y4, Y4
//#
//#	VPADDD		 Y13, Y1, Y1
//#	VPADDD		 Y13, Y2, Y2
//#	VPADDD		 Y13, Y3, Y3
//#	VPADDD		 Y13, Y4, Y4
//#
//#	VMOVDQA		 Y1, Y5 		// copy 8 seeds to Y5
//#	VMOVDQA		 Y2, Y6 		// copy 8 seeds to Y6
//#	VMOVDQA		 Y3, Y7 		// copy 8 seeds to Y7
//#	VMOVDQA		 Y4, Y8 		// copy 8 seeds to Y8
//#
//#	VEXTRACTF128 $1, Y5, X9 	// copy high 128 bit to X9
//#	VEXTRACTF128 $1, Y6, X10 	// copy high 128 bit to X10
//#	VEXTRACTF128 $1, Y7, X11 	// copy high 128 bit to X11
//#	VEXTRACTF128 $1, Y8, X12 	// copy high 128 bit to X12
//#
//#	VCVTDQ2PD	 X5, Y5 		// Convert 4 of the lower signed seed values to float64
//#	VCVTDQ2PD	 X6, Y6 		// Convert 4 of the lower signed seed values to float64
//#	VCVTDQ2PD	 X7, Y7 		// Convert 4 of the lower signed seed values to float64
//#	VCVTDQ2PD	 X8, Y8 		// Convert 4 of the lower signed seed values to float64
//#	VCVTDQ2PD	 X9, Y9 		// Convert 4 of the lower signed seed values to float64
//#	VCVTDQ2PD	 X10, Y10 		// Convert 4 of the lower signed seed values to float64
//#	VCVTDQ2PD	 X11, Y11 		// Convert 4 of the lower signed seed values to float64
//#	VCVTDQ2PD	 X12, Y12 		// Convert 4 of the lower signed seed values to float64
//#
//#	VDIVPD 		 Y7, Y5, Y5
//#	VDIVPD 		 Y7, Y6, Y6
//#	VDIVPD 		 Y7, Y7, Y7
//#	VDIVPD 		 Y7, Y8, Y8
//#	VDIVPD 		 Y7, Y9, Y9
//#	VDIVPD 		 Y7, Y10, Y10
//#	VDIVPD 		 Y7, Y11, Y11
//#	VDIVPD 		 Y7, Y12, Y12
///### End of Blob code

	VMOVDQA 	 Y5,      (SI)
	VMOVDQA 	 Y6,    32(SI)
	VMOVDQA 	 Y7,    64(SI)
	VMOVDQA 	 Y8,    96(SI)
	VMOVDQA 	 Y9,   128(SI)
	VMOVDQA 	 Y10,  160(SI)
	VMOVDQA 	 Y11,  192(SI)
	VMOVDQA 	 Y12,  224(SI)

	ADDQ	$256, SI 			//; 16 * complex128 = 256 bytes
	ADDQ	$16, BX
	CMPQ 	BX, AX
	JL		mainLoopAVX2		//; if Si >= buflen return

	VMOVDQA		 Y1,   (CX) 	//; save seed numbers
	VMOVDQA		 Y2, 32(CX) 	//; save seed numbers
	VMOVDQA		 Y3, 64(CX) 	//; save seed numbers
	VMOVDQA		 Y4, 96(CX) 	//; save seed numbers

	RET
///;### End AVX2 use


//; func fillavx(buf []complex128, seedbuf []uint32)
TEXT ·fillavx(SB),NOSPLIT,$0
///;### For AVX use
	MOVQ a+0(FP), SI    //; pointer to buffer
	MOVQ a+8(FP), AX    //; length of buffer in complex128
	//;  a+16(FP)       //; capacity of buffer, not used
	MOVQ a+24(FP), CX   //; pointer to seedbuf
	//;  a+32(FP)       //; length of seedbuff not used
	//;  a+40(FP)       //; capacity of seedbuff not used
 	MOVQ $256, BX

	VMOVDQA		   (CX), X0		//; move 128bits in to X0 containing 4 32bit seed numbers
	VMOVDQA		 16(CX), X1		//; move 128bits in to X1 containing 4 32bit seed numbers
	VMOVDQA		 32(CX), X2		//; move 128bits in to X2 containing 4 32bit seed numbers
	VMOVDQA		 48(CX), X3		//; move 128bits in to X3 containing 4 32bit seed numbers
	VMOVDQA		 64(CX), X4		//; move 128bits in to X4 containing 4 32bit seed numbers
	VMOVDQA		 80(CX), X5		//; move 128bits in to X5 containing 4 32bit seed numbers
	VMOVDQA		 96(CX), X6		//; move 128bits in to X6 containing 4 32bit seed numbers
	VMOVDQA		112(CX), X7		//; move 128bits in to X7 containing 4 32bit seed numbers
	VMOVDQA 	128(CX), X15  	//; move 128bits in to X15 containing 4 32bit increment numbers
	VMOVDQA 	160(CX), X14  	//; move 128bits in to X14 containing 4 32bit multiplier numbers

	VMOVDQA		X15, X13  	
	BYTE $0xC4; BYTE $0xC1; BYTE $0x11; BYTE $0x72; BYTE $0xF5; BYTE $0x1E; // VPSLLD 		$30, X13  
	BYTE $0xC4; BYTE $0x41; BYTE $0x7E; BYTE $0xE6; BYTE $0xED; 			// VCVTDQ2PD 	X13, Y13 
	//; Y13 now contains 4 float64 with the value (1<<30), later used with VDIVPD

mainLoopAVX:
	PMULLD X14, X0
	PMULLD X14, X1
	PMULLD X14, X2
	PMULLD X14, X3
	PMULLD X14, X4
	PMULLD X14, X5
	PMULLD X14, X6
	PMULLD X14, X7

	BYTE $0xC4; BYTE $0xC1; BYTE $0x79; BYTE $0xFE; BYTE $0xC7; // VPADDD X15, X0, X0
	BYTE $0xC4; BYTE $0xC1; BYTE $0x71; BYTE $0xFE; BYTE $0xCF; // VPADDD X15, X1, X1
	BYTE $0xC4; BYTE $0xC1; BYTE $0x69; BYTE $0xFE; BYTE $0xD7; // VPADDD X15, X2, X2
	BYTE $0xC4; BYTE $0xC1; BYTE $0x61; BYTE $0xFE; BYTE $0xDF; // VPADDD X15, X3, X3
	BYTE $0xC4; BYTE $0xC1; BYTE $0x59; BYTE $0xFE; BYTE $0xE7; // VPADDD X15, X4, X4
	BYTE $0xC4; BYTE $0xC1; BYTE $0x51; BYTE $0xFE; BYTE $0xEF; // VPADDD X15, X5, X5
	BYTE $0xC4; BYTE $0xC1; BYTE $0x49; BYTE $0xFE; BYTE $0xF7; // VPADDD X15, X6, X6
	BYTE $0xC4; BYTE $0xC1; BYTE $0x41; BYTE $0xFE; BYTE $0xFF; // VPADDD X15, X7, X7
//
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xC0 // VCVTDQ2PD X0, Y8
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xC9 // VCVTDQ2PD X1, Y9
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xD2 // VCVTDQ2PD X2, Y10
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xDB // VCVTDQ2PD X3, Y11
//
	BYTE $0xC4; BYTE $0x41; BYTE $0x3D; BYTE $0x5E; BYTE $0xC5; // VDIVPD Y13, Y8, Y8
	BYTE $0xC4; BYTE $0x41; BYTE $0x35; BYTE $0x5E; BYTE $0xCD; // VDIVPD Y13, Y9, Y9
	BYTE $0xC4; BYTE $0x41; BYTE $0x2D; BYTE $0x5E; BYTE $0xD5; // VDIVPD Y13, Y10, Y10
	BYTE $0xC4; BYTE $0x41; BYTE $0x25; BYTE $0x5E; BYTE $0xDD; // VDIVPD Y13, Y11, Y11

	VMOVDQA Y8,    (SI)
	VMOVDQA Y9,  32(SI)
	VMOVDQA Y10, 64(SI)
	VMOVDQA Y11, 96(SI)

	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xC4; // VCVTDQ2PD X4, Y8
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xCD; // VCVTDQ2PD X5, Y9
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xD6; // VCVTDQ2PD X6, Y10
	BYTE $0xC5; BYTE $0x7E; BYTE $0xE6; BYTE $0xDF; // VCVTDQ2PD X7, Y11

	BYTE $0xC4; BYTE $0x41; BYTE $0x3D; BYTE $0x5E; BYTE $0xC5; // VDIVPD Y13, Y8, Y8
	BYTE $0xC4; BYTE $0x41; BYTE $0x35; BYTE $0x5E; BYTE $0xCD; // VDIVPD Y13, Y9, Y9
	BYTE $0xC4; BYTE $0x41; BYTE $0x2D; BYTE $0x5E; BYTE $0xD5; // VDIVPD Y13, Y10, Y10
	BYTE $0xC4; BYTE $0x41; BYTE $0x25; BYTE $0x5E; BYTE $0xDD; // VDIVPD Y13, Y11, Y11

	VMOVDQA Y8,  128(SI)
	VMOVDQA Y9,  160(SI)
	VMOVDQA Y10, 192(SI)
	VMOVDQA Y11, 224(SI)

	ADDQ	$256, SI 		//; 16 * complex128 = 256 bytes
	ADDQ	$16, BX
	CMPQ 	BX, AX
	JL		mainLoopAVX 	//; if Si >= buflen return

	VMOVDQA X0,    (CX) 	//; move 128bits in to X0 containing 4 32bit seed numbers
	VMOVDQA X1,  16(CX) 	//; move 128bits in to X1 containing 4 32bit seed numbers
	VMOVDQA X2,  32(CX) 	//; move 128bits in to X2 containing 4 32bit seed numbers
	VMOVDQA X3,  48(CX) 	//; move 128bits in to X3 containing 4 32bit seed numbers
	VMOVDQA X4,  64(CX) 	//; move 128bits in to X4 containing 4 32bit seed numbers
	VMOVDQA X5,  80(CX) 	//; move 128bits in to X5 containing 4 32bit seed numbers
	VMOVDQA X6,  96(CX) 	//; move 128bits in to X6 containing 4 32bit seed numbers
	VMOVDQA X7, 112(CX) 	//; move 128bits in to X7 containing 4 32bit seed numbers

	RET
///;### End AVX use	
