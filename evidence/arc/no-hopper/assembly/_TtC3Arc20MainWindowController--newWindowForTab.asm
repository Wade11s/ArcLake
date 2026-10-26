
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
10031ce70: d10103ff    	sub	sp, sp, #0x40
10031ce74: a9024ff4    	stp	x20, x19, [sp, #0x20]
10031ce78: a9037bfd    	stp	x29, x30, [sp, #0x30]
10031ce7c: 9100c3fd    	add	x29, sp, #0x30
10031ce80: aa0003f4    	mov	x20, x0
10031ce84: b4000162    	cbz	x2, 0x10031ceb0 <__text+0x319d78>
10031ce88: aa0203f3    	mov	x19, x2
10031ce8c: aa1403e0    	mov	x0, x20
10031ce90: 94c5401e    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
10031ce94: aa1303e0    	mov	x0, x19
10031ce98: 94c54376    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
10031ce9c: 910003e8    	mov	x8, sp
10031cea0: 94c52fe5    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
10031cea4: aa1303e0    	mov	x0, x19
10031cea8: 94c5436c    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
10031ceac: 14000005    	b	0x10031cec0 <__text+0x319d88>
10031ceb0: 6f00e400    	movi.2d	v0, #0000000000000000
10031ceb4: ad0003e0    	stp	q0, q0, [sp]
10031ceb8: aa1403e0    	mov	x0, x20
10031cebc: 94c54013    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
10031cec0: 910003e0    	mov	x0, sp
10031cec4: 97fffef7    	bl	0x10031caa0 <__text+0x319968>
10031cec8: aa1403e0    	mov	x0, x20
10031cecc: 94c5400c    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
10031ced0: f0020201    	adrp	x1, 0x10435f000 <_xmlXPathRegisterNs+0x10435f000>
10031ced4: 913a2021    	add	x1, x1, #0xe88
10031ced8: d0018d42    	adrp	x2, 0x1034c6000 <_xmlXPathRegisterNs+0x1034c6000>
10031cedc: 9129c042    	add	x2, x2, #0xa70
10031cee0: 910003e0    	mov	x0, sp
10031cee4: 97f3a938    	bl	0x1000073c4 <__text+0x428c>
10031cee8: a9437bfd    	ldp	x29, x30, [sp, #0x30]
10031ceec: a9424ff4    	ldp	x20, x19, [sp, #0x20]
10031cef0: 910103ff    	add	sp, sp, #0x40
10031cef4: d65f03c0    	ret
