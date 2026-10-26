
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
10031b6cc: d10103ff    	sub	sp, sp, #0x40
10031b6d0: a9024ff4    	stp	x20, x19, [sp, #0x20]
10031b6d4: a9037bfd    	stp	x29, x30, [sp, #0x30]
10031b6d8: 9100c3fd    	add	x29, sp, #0x30
10031b6dc: aa0203f3    	mov	x19, x2
10031b6e0: aa0203e0    	mov	x0, x2
10031b6e4: 94c54963    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
10031b6e8: 910003e8    	mov	x8, sp
10031b6ec: aa1303e0    	mov	x0, x19
10031b6f0: 94c535d1    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
10031b6f4: aa1303e0    	mov	x0, x19
10031b6f8: 94c54958    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
10031b6fc: 90020008    	adrp	x8, 0x10431b000 <_xmlXPathRegisterNs+0x10431b000>
10031b700: f946bd00    	ldr	x0, [x8, #0xd78]
10031b704: 94c545f8    	bl	0x10346cee4 <_xmlXPathRegisterNs+0x10346cee4>
10031b708: b001ffa8    	adrp	x8, 0x104310000 <_xmlXPathRegisterNs+0x104310000>
10031b70c: f9448d01    	ldr	x1, [x8, #0x918]
10031b710: 94c545e6    	bl	0x10346cea8 <_xmlXPathRegisterNs+0x10346cea8>
10031b714: aa1d03fd    	mov	x29, x29
10031b718: 94c54605    	bl	0x10346cf2c <_xmlXPathRegisterNs+0x10346cf2c>
10031b71c: aa0003f3    	mov	x19, x0
10031b720: 946bee78    	bl	0x101e17100 <__text+0x1e13fc8>
10031b724: f9400002    	ldr	x2, [x0]
10031b728: 9001ffc8    	adrp	x8, 0x104313000 <_xmlXPathRegisterNs+0x104313000>
10031b72c: f9425901    	ldr	x1, [x8, #0x4b0]
10031b730: aa1303e0    	mov	x0, x19
10031b734: d2800003    	mov	x3, #0x0                ; =0
10031b738: 94c545dc    	bl	0x10346cea8 <_xmlXPathRegisterNs+0x10346cea8>
10031b73c: aa1303e0    	mov	x0, x19
10031b740: 94c545ef    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
10031b744: 910003e0    	mov	x0, sp
10031b748: 97f3deac    	bl	0x1000131f8 <__text+0x100c0>
10031b74c: a9437bfd    	ldp	x29, x30, [sp, #0x30]
10031b750: a9424ff4    	ldp	x20, x19, [sp, #0x20]
10031b754: 910103ff    	add	sp, sp, #0x40
10031b758: d65f03c0    	ret
