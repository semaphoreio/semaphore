(globalThis as any).window = document.defaultView;
(globalThis as any).customElements = { define: (): void => undefined, get: (): void => undefined };
(globalThis as any).location = new URL(`http://localhost/`);
