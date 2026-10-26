
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
100320444: d10183ff    	sub	sp, sp, #0x60
100320448: a90357f6    	stp	x22, x21, [sp, #0x30]
10032044c: a9044ff4    	stp	x20, x19, [sp, #0x40]
100320450: a9057bfd    	stp	x29, x30, [sp, #0x50]
100320454: 910143fd    	add	x29, sp, #0x50
100320458: aa0003f3    	mov	x19, x0
10032045c: b4000162    	cbz	x2, 0x100320488 <__text+0x31d350>
100320460: aa0203f4    	mov	x20, x2
100320464: aa1303e0    	mov	x0, x19
100320468: 94c532a8    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
10032046c: aa1403e0    	mov	x0, x20
100320470: 94c53600    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
100320474: 910043e8    	add	x8, sp, #0x10
100320478: 94c5226f    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
10032047c: aa1403e0    	mov	x0, x20
100320480: 94c535f6    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
100320484: 14000005    	b	0x100320498 <__text+0x31d360>
100320488: 6f00e400    	movi.2d	v0, #0000000000000000
10032048c: ad0083e0    	stp	q0, q0, [sp, #0x10]
100320490: aa1303e0    	mov	x0, x19
100320494: 94c5329d    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
100320498: 90020268    	adrp	x8, 0x10436c000 <_xmlXPathRegisterNs+0x10436c000>
10032049c: f9433908    	ldr	x8, [x8, #0x670]
1003204a0: f8686a74    	ldr	x20, [x19, x8]
1003204a4: d2800000    	mov	x0, #0x0                ; =0
1003204a8: 94888f03    	bl	0x1025440b4 <__text+0x2540f7c>
1003204ac: aa0003f5    	mov	x21, x0
1003204b0: 94c5344c    	bl	0x10346d5e0 <_xmlXPathRegisterNs+0x10346d5e0>
1003204b4: aa0003f6    	mov	x22, x0
1003204b8: aa0103e0    	mov	x0, x1
1003204bc: aa1503e1    	mov	x1, x21
1003204c0: 528000e2    	mov	w2, #0x7                ; =7
1003204c4: 94c535ac    	bl	0x10346db74 <_xmlXPathRegisterNs+0x10346db74>
1003204c8: d2800088    	mov	x8, #0x4                ; =4
1003204cc: f2e20008    	movk	x8, #0x1000, lsl #48
1003204d0: aa0802c8    	orr	x8, x22, x8
1003204d4: f90003e8    	str	x8, [sp]
1003204d8: 390023ff    	strb	wzr, [sp, #0x8]
1003204dc: 910003e0    	mov	x0, sp
1003204e0: 941348de    	bl	0x1007f2858 <__text+0x7ef720>
1003204e4: 94c53583    	bl	0x10346daf0 <_xmlXPathRegisterNs+0x10346daf0>
1003204e8: f00201e1    	adrp	x1, 0x10435f000 <_xmlXPathRegisterNs+0x10435f000>
1003204ec: 913a2021    	add	x1, x1, #0xe88
1003204f0: d0018d22    	adrp	x2, 0x1034c6000 <_xmlXPathRegisterNs+0x1034c6000>
1003204f4: 9129c042    	add	x2, x2, #0xa70
1003204f8: 910043e0    	add	x0, sp, #0x10
1003204fc: 97f39bb2    	bl	0x1000073c4 <__text+0x428c>
100320500: aa1303e0    	mov	x0, x19
100320504: 94c5327e    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
100320508: aa1603e0    	mov	x0, x22
10032050c: 94c53579    	bl	0x10346daf0 <_xmlXPathRegisterNs+0x10346daf0>
100320510: a9457bfd    	ldp	x29, x30, [sp, #0x50]
100320514: a9444ff4    	ldp	x20, x19, [sp, #0x40]
100320518: a94357f6    	ldp	x22, x21, [sp, #0x30]
10032051c: 910183ff    	add	sp, sp, #0x60
100320520: d65f03c0    	ret
