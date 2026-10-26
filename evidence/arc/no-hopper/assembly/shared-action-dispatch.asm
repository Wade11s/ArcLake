
/tmp/arclake-arc-arm64.macho:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100003138 <__text>:
10031a8e4: d10143ff    	sub	sp, sp, #0x50
10031a8e8: a90257f6    	stp	x22, x21, [sp, #0x20]
10031a8ec: a9034ff4    	stp	x20, x19, [sp, #0x30]
10031a8f0: a9047bfd    	stp	x29, x30, [sp, #0x40]
10031a8f4: 910103fd    	add	x29, sp, #0x40
10031a8f8: aa0303f3    	mov	x19, x3
10031a8fc: aa0203f4    	mov	x20, x2
10031a900: aa0003f5    	mov	x21, x0
10031a904: aa0203e0    	mov	x0, x2
10031a908: 94c54cda    	bl	0x10346dc70 <_xmlXPathRegisterNs+0x10346dc70>
10031a90c: aa1503e0    	mov	x0, x21
10031a910: 94c5497e    	bl	0x10346cf08 <_xmlXPathRegisterNs+0x10346cf08>
10031a914: aa0003f5    	mov	x21, x0
10031a918: 910003e8    	mov	x8, sp
10031a91c: aa1403e0    	mov	x0, x20
10031a920: 94c53945    	bl	0x103468e34 <_xmlXPathRegisterNs+0x103468e34>
10031a924: aa1403e0    	mov	x0, x20
10031a928: 94c54ccc    	bl	0x10346dc58 <_xmlXPathRegisterNs+0x10346dc58>
10031a92c: 910003e0    	mov	x0, sp
10031a930: aa1503f4    	mov	x20, x21
10031a934: aa1303e1    	mov	x1, x19
10031a938: 94001811    	bl	0x10032097c <__text+0x31d844>
10031a93c: aa1503e0    	mov	x0, x21
10031a940: 94c5496f    	bl	0x10346cefc <_xmlXPathRegisterNs+0x10346cefc>
10031a944: 910003e0    	mov	x0, sp
10031a948: 97f3e22c    	bl	0x1000131f8 <__text+0x100c0>
10031a94c: a9447bfd    	ldp	x29, x30, [sp, #0x40]
10031a950: a9434ff4    	ldp	x20, x19, [sp, #0x30]
10031a954: a94257f6    	ldp	x22, x21, [sp, #0x20]
10031a958: 910143ff    	add	sp, sp, #0x50
10031a95c: d65f03c0    	ret
