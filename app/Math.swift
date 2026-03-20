import simd

struct Uniforms {
    var modelViewProjectionMatrix: matrix_float4x4
}

struct Math {
    static func rotationMatrix(angle: Float, axis: simd_float3) -> matrix_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        let naxis = normalize(axis)
        let x = naxis.x
        let y = naxis.y
        let z = naxis.z
        
        let matrix = matrix_float4x4(
            [c + x*x*(1-c),   x*y*(1-c) - z*s, x*z*(1-c) + y*s, 0],
            [y*x*(1-c) + z*s, c + y*y*(1-c),   y*z*(1-c) - x*s, 0],
            [z*x*(1-c) - y*s, z*y*(1-c) + x*s, c + z*z*(1-c),   0],
            [0,               0,               0,               1]
        )
        return matrix
    }
    
    static func perspectiveMatrix(fovy: Float, aspect: Float, near: Float, far: Float) -> matrix_float4x4 {
        let ys = 1 / tan(fovy * 0.5)
        let xs = ys / aspect
        let zs = far / (near - far)
        
        return matrix_float4x4(
            [xs, 0,  0,           0],
            [0,  ys, 0,           0],
            [0,  0,  zs,          -1],
            [0,  0,  near * zs,  0]
        )
    }
    
    static func identityMatrix() -> matrix_float4x4 {
        return matrix_identity_float4x4
    }
}
