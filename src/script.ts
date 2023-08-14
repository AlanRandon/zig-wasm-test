import Alpine from "alpinejs";

declare global {
	interface Window {
		Alpine: typeof Alpine;
		drawCanvas: typeof drawCanvas;
	}
}

type Exports = {
	memory: WebAssembly.Memory;
	draw: (
		buffer: number,
		width: number,
		height: number,
		realStart: number,
		imaginaryStart: number,
		scaledWidth: number
	) => void;
	free: (ptr: number) => void;
	alloc: (len: number) => number;
};

let exports: Exports;

type DrawOptions = {
	ctx: CanvasRenderingContext2D;
	realStart: number;
	imaginaryStart: number;
	scaledWidth: number;
};

function draw(width: number, height: number, opts: DrawOptions): ImageData {
	const len = width * height * 4;
	const ptr = exports.alloc(len);

	exports.draw(ptr, width, height, opts.realStart, opts.imaginaryStart, opts.scaledWidth);

	const array = new Uint8ClampedArray(exports.memory.buffer, ptr, len);
	const data = new ImageData(array, width, height);

	exports.free(ptr);

	return data;
}

function drawCanvas(opts: DrawOptions): void {
	const canvas = opts.ctx.canvas;
	const data = draw(canvas.width, canvas.height, opts);
	opts.ctx.putImageData(data, 0, 0);
}

function decodeString(ptr: number, len: number): string {
	const slice = new Uint8Array(exports.memory.buffer, ptr, len);
	return new TextDecoder().decode(slice);
}

(async function main() {
	const { instance } = await WebAssembly.instantiateStreaming(fetch("/zig-wasm.wasm"), {
		env: {
			["throw"](ptr: number, len: number): never {
				throw new Error(decodeString(ptr, len));
			},
			consoleLog(ptr: number, len: number): void {
				console.log(decodeString(ptr, len));
			},
		}
	});

	exports = instance.exports as Exports;

	window.drawCanvas = drawCanvas;
	window.Alpine = Alpine;

	Alpine.start();
})()
