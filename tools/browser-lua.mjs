// Run the browser build's WASI interpreter image under Node: the
// 'make browser-test' smoke test, not a delivery.
//
//   node tools/browser-lua.mjs src/browser/lua.wasm [lua arguments]
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';

const [image, ...args] = process.argv.slice(2);
const wasi = new WASI({ version: 'preview1', args: ['lua', ...args], returnOnExit: true });
const { instance } = await WebAssembly.instantiate(await readFile(image),
  { wasi_snapshot_preview1: wasi.wasiImport });
process.exitCode = wasi.start(instance);
