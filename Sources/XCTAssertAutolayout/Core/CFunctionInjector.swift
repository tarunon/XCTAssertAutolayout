//
//  CFunctionInjector.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/21.
//  Copyright © 2019 tarunon. All rights reserved.
//

import Foundation

enum CFunctionInjector {
    private struct original_function {
        var pointer: UnsafeMutablePointer<__int64_t>
        var original_offset: __int64_t = 0
        
        func reset() {
            pointer.pointee = original_offset
        }
    }
    
    // Ref: https://academy.realm.io/jp/posts/sash-zats-swift-swizzling/
    private struct swift_func_wrapper {
        var trampoline_ptr: UnsafeMutablePointer<uintptr_t>
        var function_object: UnsafeMutablePointer<swift_func_object>
    }
    
    // Ref: https://academy.realm.io/jp/posts/sash-zats-swift-swizzling/
    private struct swift_func_object {
        var original_type_ptr: UnsafeMutablePointer<uintptr_t>
        var unknown: UnsafeMutablePointer<UInt64>
        var address: uintptr_t
        var selfPtr: UnsafeMutablePointer<uintptr_t>
    }
    
    private static var injected_functions: [Int: original_function] = [:]
    
    /// Inject swift function to c function.
    /// Objective-C bridging is not work in injected function.
    /// The injected functions argument and return value should use original type or `UnsafeRawPointer`.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameters:
    ///   - symbol: c function name.
    ///   - target: function pointer. should use `withUnsafePointer(to:_:)`.
    static func inject(_ symbol: UnsafePointer<Int8>!, _ target: UnsafeRawPointer) {
        assert(Thread.isMainThread)
        
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        guard let origin = dlsym(RTLD_DEFAULT, symbol)?.assumingMemoryBound(to: __int64_t.self) else { return }
        
        injected_functions[Int(bitPattern: origin)] = original_function(pointer: origin, original_offset: origin.pointee)
        
        // get actual function target
        let target = UnsafeMutableRawPointer(bitPattern: target.assumingMemoryBound(to: swift_func_wrapper.self).pointee.function_object.pointee.address)
        
        // make the memory containing the original function writable
        let pageSize = sysconf(_SC_PAGESIZE)
        let start = Int(bitPattern: origin)
        let end = start + 1
        let pageStart = start & -pageSize
        mprotect(UnsafeMutableRawPointer(bitPattern: pageStart), end - pageStart, PROT_READ | PROT_WRITE | PROT_EXEC)
        
        // Calculate the relative offset needed for the jump instruction.
        // Since relative jumps are calculated from the address of the next instruction,
        // 5 bytes must be added to the original address (jump instruction is 5 bytes).
        let offset = __int64_t(Int(bitPattern: target)) - (__int64_t(Int(bitPattern: origin)) + 5 * __int64_t(MemoryLayout.size(ofValue: CChar())))
        
        
        // Set the first instruction of the original function to be a jump to the replacement function.
        // 0xe9 is the x86 opcode for an unconditional relative jump.
        let instruction = 0xe9 | offset << 8
        
        origin.pointee = instruction
    }
    
    /// Reset function injection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter symbol: c function name.
    static func reset(_ symbol: UnsafePointer<Int8>!) {
        assert(Thread.isMainThread)
        
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        guard let origin = dlsym(RTLD_DEFAULT, symbol)?.assumingMemoryBound(to: __int64_t.self) else { return }
        
        injected_functions[Int(bitPattern: origin)]?.reset()
        injected_functions[Int(bitPattern: origin)] = nil
    }
}
