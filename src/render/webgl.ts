export class Program {
    private _gl: WebGLRenderingContext
    private _glProgram: WebGLProgram
    private _shaderErrorNumber = 0

    constructor(gl: WebGLRenderingContext) {
        this._gl = gl
        this._glProgram = gl.createProgram()
    }

    public get shaderErrorNumber(): number {
        return this._shaderErrorNumber
    }

    public get glProgram(): WebGLProgram {
        return this._glProgram
    }

    public static from(
        gl: WebGLRenderingContext,
        vertexCode: string,
        fragmantCode: string
    ): WebGLProgram | null {
        let program: Program = new Program(gl)
        program.loadVertexShader(vertexCode)
        program.loadFragmentShader(fragmantCode)

        let error: string = program.link()
        if (!error) {
            console.error('Error in program linking:' + error)
            program.delete()
            return null
        }
        return program
    }

    public link(): string | null {
        this._gl.linkProgram(this._glProgram)
        let linked = this._gl.getProgramParameter(
            this._glProgram,
            this._gl.LINK_STATUS
        )

        if (!linked) {
            let lastError: string = this._gl.getProgramInfoLog(this._glProgram)
            return lastError
        }
        return null
    }

    public delete(): void {
        this._gl.deleteProgram(this._glProgram)
    }

    public attachShader(shader: string): void {
        this._gl.attachShader(this._glProgram, shader)
    }

    public getAttributeLocation(attr: string): number {
        return this._gl.getAttribLocation(this._glProgram, attr)
    }

    public getUniformLocation(attr: string): WebGLUniformLocation {
        return this._gl.getUniformLocation(this._glProgram, attr)
    }

    public loadVertexShader(code: string): void {
        this.loadShader('vertex', this._gl.VERTEX_SHADER, code)
    }

    public loadFragmentShader(code: string): void {
        this.loadShader('fragment', this._gl.FRAGMENT_SHADER, code)
    }

    public loadShader(
        name: string,
        type: number,
        code: string
    ): WebGLShader | null {
        let shader: WebGLShader | null = this.loadShaderWithContext(
            this._gl,
            name,
            code,
            type
        )
        return shader
    }

    public loadShaderWithContext(
        gl: WebGLRenderingContext,
        name: string,
        shaderSource: string,
        shaderType: number
    ): WebGLShader | null {
        let shader = gl.createShader(shaderType)
        gl.shaderSource(shader, shaderSource)
        gl.compileShader(shader)

        let compiled: string = gl.getShaderInfoLog(shader)
        if (!compiled) {
            let lastError: string = gl.getShaderInfoLog(shader)
            console.error(`*** Error compiling ${name} shader:\n${lastError}`)

            let logfname = `printShaderError${this._shaderErrorNumber}`
            console.error(`Use '${logfname}' to see its source`)

            window[logfname] = console.error(this.listCode(shaderSource))
            this._shaderErrorNumber += 1

            gl.deleteShader(shader)
            return null
        }
        return shader
    }

    public listCode(code: string): string {
        let lines = code.split(/\r?\n/)
        let maxDigits = this.digitsCount(lines.length)

        let listLines: string[] = []
        let lineNumber = 0

        for (let line of lines) {
            lineNumber += 1
            let digits: number = this.digitsCount(lineNumber)
            let spaces: number = maxDigits - digits
            let linePfx = ' '.repeat(spaces) + lineNumber
            let listLine: string = linePfx + line
            listLines.push(listLine)
        }

        let listing: string = listLines.join('\n')
        return listing
    }

    public digitsCount(number: number): number {
        return Math.floor(Math.log10(number)) + 1
    }
}
