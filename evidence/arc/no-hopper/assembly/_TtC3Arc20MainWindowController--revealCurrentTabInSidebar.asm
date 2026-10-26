
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
100320814: d10183ff    	sub	sp, sp, #0x60
100320818: a90357f6    	stp	x22, x21, [sp, #0x30]
10032081c: a9044ff4    	stp	x20, x19, [sp, #0x40]
100320820: a9057bfd    	stp	x29, x30, [sp, #0x50]
100320824: 910143fd    	add	x29, sp, #0x50
100320828: aa0203f3    	mov	x19, x2
10032082c: aa0003f4    	mov	x20, x0
100320830: aa0203e0    	mov	x0, x2
100320834: 94c5350f    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
100320838: aa1403e0    	mov	x0, x20
10032083c: 94c531b3    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
100320840: aa0003f5    	mov	x21, x0
100320844: 910043e8    	add	x8, sp, #0x10
100320848: aa1303e0    	mov	x0, x19
10032084c: 94c5217a    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
100320850: aa1303e0    	mov	x0, x19
100320854: 94c53501    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
100320858: 90020268    	adrp	x8, 0x10436c000 <_xmlXPathRegisterNs+0x10436c000>
10032085c: f9433908    	ldr	x8, [x8, #0x670]
100320860: f8686ab4    	ldr	x20, [x21, x8]
100320864: 528003a8    	mov	w8, #0x1d               ; =29
100320868: f90003e8    	str	x8, [sp]
10032086c: 52800028    	mov	w8, #0x1                ; =1
100320870: 390023e8    	strb	w8, [sp, #0x8]
100320874: 910003e0    	mov	x0, sp
100320878: 941347f8    	bl	0x1007f2858 <__text+0x7ef720>
10032087c: 94c5349d    	bl	0x10346daf0 <_xmlXPathRegisterNs+0x10346daf0>
100320880: 910043e0    	add	x0, sp, #0x10
100320884: 97f3ca5d    	bl	0x1000131f8 <__text+0x100c0>
100320888: aa1503e0    	mov	x0, x21
10032088c: 94c5319c    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
100320890: a9457bfd    	ldp	x29, x30, [sp, #0x50]
100320894: a9444ff4    	ldp	x20, x19, [sp, #0x40]
100320898: a94357f6    	ldp	x22, x21, [sp, #0x30]
10032089c: 910183ff    	add	sp, sp, #0x60
1003208a0: d65f03c0    	ret
