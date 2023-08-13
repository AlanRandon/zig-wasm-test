let memory: WebAssembly.Memory;

function decodeUTF8String(ptr: number, len: number): string {
	const slice = new Uint8Array(memory.buffer, ptr, len)
	return new TextDecoder().decode(slice);
}

WebAssembly.instantiateStreaming(fetch("/zig-wasm.wasm"), {
	env: {
		["throw"](ptr: number, len: number): never {
			throw new Error(decodeUTF8String(ptr, len));
		},
		log(ptr: number, len: number): void {
			console.log(decodeUTF8String(ptr, len));
		}
	}
}).then((result) => {
	memory = result.instance.exports.memory as WebAssembly.Memory;

	const add = result.instance.exports.add as (a: number, b: number) => number;

	console.log(add(1, 2));
});
