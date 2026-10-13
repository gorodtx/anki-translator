import { useEffect, useRef, useState, type HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

const vertexShaderGLSL = `attribute vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}`;
const fragmentShaderGLSL = `
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;
uniform vec3 u_colorBottom;
uniform vec3 u_colorMid;
uniform vec3 u_colorTop;
uniform float u_speed;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);float a=hash(i);float b=hash(i+vec2(1.0,0.0));float c=hash(i+vec2(0.0,1.0));float d=hash(i+vec2(1.0,1.0));vec2 u=f*f*(3.0-2.0*f);return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;}
float fbm(vec2 p,float t){float v=0.0;float a=0.5;float fi=0.0;mat2 rot=mat2(0.86,0.51,-0.51,0.86);for(int i=0;i<6;i++){vec2 morph=vec2(sin(t*0.5+fi),cos(t*0.3-fi))*0.05;v+=a*noise(p+morph);p=rot*p*2.0;a*=0.5;fi+=1.0;}return v;}
void main(){vec2 uv=gl_FragCoord.xy/u_resolution;float t=u_time*u_speed;vec2 aspect=vec2(u_resolution.x/max(u_resolution.y,1.0),1.0);vec2 p=(uv-0.5)*aspect;vec2 wind=vec2(t*0.1,t*0.02);float pattern=fbm(p*2.2-wind,t);float low=smoothstep(0.3,0.65,pattern);float high=smoothstep(0.7,0.95,pattern);vec3 color=mix(u_colorBottom,u_colorMid,low);color=mix(color,u_colorTop,high);gl_FragColor=vec4(color,1.0);}
`;

interface CloudscapeProps extends HTMLAttributes<HTMLDivElement> {
  speed?: number;
  colorBottom?: string;
  colorMid?: string;
  colorTop?: string;
}

function rgb(hex: string): [number, number, number] {
  const value = /^#?[\da-f]{6}$/i.test(hex.trim()) ? hex.replace('#', '').trim() : '87ceeb';
  return [parseInt(value.slice(0, 2), 16) / 255, parseInt(value.slice(2, 4), 16) / 255, parseInt(value.slice(4, 6), 16) / 255];
}

export default function Cloudscape({ children, className, speed = 0.18, colorBottom = '#87ceeb', colorMid = '#f8f8f8', colorTop = '#ffffff', ...props }: CloudscapeProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const hostRef = useRef<HTMLDivElement>(null);
  const [epoch, setEpoch] = useState(0);
  useEffect(() => {
    const canvas = canvasRef.current; const host = hostRef.current;
    if (!canvas || !host) return;
    const gl = canvas.getContext('webgl', { antialias: false, alpha: false });
    if (!gl) return;
    const shaders: WebGLShader[] = [];
    const program = gl.createProgram();
    const buffer = gl.createBuffer();
    const release = () => { if (buffer) gl.deleteBuffer(buffer); if (program) gl.deleteProgram(program); shaders.forEach(shader => gl.deleteShader(shader)); };
    const compile = (type: number, source: string) => {
      const shader = gl.createShader(type); if (!shader) return null;
      shaders.push(shader); gl.shaderSource(shader, source); gl.compileShader(shader);
      return gl.getShaderParameter(shader, gl.COMPILE_STATUS) ? shader : null;
    };
    const vertex = compile(gl.VERTEX_SHADER, vertexShaderGLSL);
    const fragment = compile(gl.FRAGMENT_SHADER, fragmentShaderGLSL);
    if (!program || !buffer || !vertex || !fragment) { release(); return; }
    gl.attachShader(program, vertex); gl.attachShader(program, fragment); gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) { release(); return; }
    gl.useProgram(program);
    const position = gl.getAttribLocation(program, 'position');
    if (position < 0) { release(); return; }
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(position); gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
    const resolution = gl.getUniformLocation(program, 'u_resolution');
    const time = gl.getUniformLocation(program, 'u_time');
    gl.uniform3fv(gl.getUniformLocation(program, 'u_colorBottom'), rgb(colorBottom));
    gl.uniform3fv(gl.getUniformLocation(program, 'u_colorMid'), rgb(colorMid));
    gl.uniform3fv(gl.getUniformLocation(program, 'u_colorTop'), rgb(colorTop));
    gl.uniform1f(gl.getUniformLocation(program, 'u_speed'), speed);
    let frame = 0; let inView = true; let lastDraw = 0;
    const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
    const start = performance.now();
    const draw = (now: number) => {
      if (now - lastDraw >= 32 || reduceMotion.matches) {
        gl.uniform1f(time, reduceMotion.matches ? 0 : (now - start) / 1000);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); lastDraw = now;
      }
      if (!reduceMotion.matches && !document.hidden && inView && !gl.isContextLost()) frame = requestAnimationFrame(draw);
    };
    const resume = () => {
      cancelAnimationFrame(frame);
      if (!document.hidden && inView && !gl.isContextLost()) { lastDraw = 0; frame = requestAnimationFrame(draw); }
    };
    const resize = () => {
      const { width, height } = host.getBoundingClientRect();
      const ratio = Math.min(devicePixelRatio || 1, 1.25, Math.sqrt(900_000 / Math.max(1, width * height)));
      canvas.width = Math.max(1, Math.round(width * ratio)); canvas.height = Math.max(1, Math.round(height * ratio));
      gl.viewport(0, 0, canvas.width, canvas.height); gl.uniform2f(resolution, canvas.width, canvas.height);
      gl.uniform1f(time, 0); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); resume();
    };
    const observer = new ResizeObserver(resize); observer.observe(host); resize();
    const visibility = new IntersectionObserver(([entry]) => { inView = entry?.isIntersecting ?? false; resume(); }); visibility.observe(host);
    const lost = (event: Event) => { event.preventDefault(); cancelAnimationFrame(frame); canvas.style.visibility = 'hidden'; };
    const restored = () => { canvas.style.visibility = ''; setEpoch(value => value + 1); };
    document.addEventListener('visibilitychange', resume); reduceMotion.addEventListener('change', resume);
    canvas.addEventListener('webglcontextlost', lost); canvas.addEventListener('webglcontextrestored', restored);
    return () => {
      cancelAnimationFrame(frame); observer.disconnect(); visibility.disconnect();
      document.removeEventListener('visibilitychange', resume); reduceMotion.removeEventListener('change', resume);
      canvas.removeEventListener('webglcontextlost', lost); canvas.removeEventListener('webglcontextrestored', restored); release();
    };
  }, [speed, colorBottom, colorMid, colorTop, epoch]);
  return <div ref={hostRef} className={cn('cloudscape', className)} {...props}>
    <canvas ref={canvasRef} className="cloud-canvas" aria-hidden="true" />{children}
  </div>;
}
