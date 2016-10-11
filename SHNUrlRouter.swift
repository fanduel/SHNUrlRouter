//
//  SHNUrlRouter.swift
//  SHNUrlRouter
//
//	Copyright (c) 2015 Shaun Harrison
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//	SOFTWARE.
//

import Foundation

private typealias PatternRoutePair = (CompiledPattern, SHNUrlRoute)
private typealias CompiledPattern = (NSRegularExpression, [String])

private func regexReplace(expression: NSRegularExpression, replacement: String, target: NSMutableString) {
    expression.replaceMatches(in: target, options: [], range: NSMakeRange(0, target.length), withTemplate: replacement)
}

public class SHNUrlRouter {
    private var patterns = Array<PatternRoutePair>()
    private var aliases = Dictionary<String, String>()
    private let unescapePattern = try! NSRegularExpression(pattern: "\\\\([\\{\\}\\?])", options: [])
    private let parameterPattern = try! NSRegularExpression(pattern: "\\{([a-zA-Z0-9_\\-]+)\\}", options: [])
    private let optionalParameterPattern = try! NSRegularExpression(pattern: "(\\\\\\/)?\\{([a-zA-Z0-9_\\-]+)\\?\\}", options: [])
    private let slashCharacterSet = CharacterSet(charactersIn: "/")
    
    public init() { }
    
    /**
     Add an parameter alias
     
     - parameter alias: Name of the parameter
     - parameter pattern: Regex pattern to match on
     */
    public func add(alias: String, pattern: String) {
        self.aliases[alias] = pattern
    }
    
    
    
    /**
     Register a route pattern with full handler
     
     - parameter pattern: Route pattern
     - parameter handler: Full handler to call when route is dispatched
     
     - returns: New route instance for the pattern
     */
    public func register(_ routePattern: String, _ handler: @escaping SHNUrlRouteHandler) -> SHNUrlRoute {
        return self.register(routePatterns: [routePattern], handler: handler)
    }
    
    /**
     Register route patterns with full handler
     
     - parameter pattern: Route patterns
     - parameter handler: Full handler to call when route is dispatched
     
     - returns: New route instance for the patterns
     */
    public func register(routePatterns: [String], handler: @escaping SHNUrlRouteHandler) -> SHNUrlRoute {
        assert(routePatterns.count > 0, "Route patterns must contain at least one pattern")
        
        let route = SHNUrlRoute(router: self, pattern: routePatterns.first!, handler: handler)
        self.register(routePatterns: routePatterns, route: route)
        return route
    }
    
    internal func register(routePatterns: [String], route: SHNUrlRoute) {
        for routePattern in routePatterns {
            let matchingPatternRoute = SHNUrlRoute(router: self, pattern: routePattern, handler: route.handler)
            self.patterns.append(PatternRoutePair(self.compile(pattern: routePattern), matchingPatternRoute))
        }
    }
    
    private func normalizePath(path: String?) -> String {
        if let path = path?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), path.characters.count > 0 {
            return "/" + path.trimmingCharacters(in: slashCharacterSet)
        } else {
            return "/"
        }
    }
    
    private func compile(pattern: String) -> CompiledPattern {
        // Escape pattern
        let compiled = NSMutableString(string: NSRegularExpression.escapedPattern(for: self.normalizePath(path: pattern)))
        
        // Unescape path parameters
        regexReplace(expression: unescapePattern, replacement: "$1", target: compiled)
        
        // Extract out optional parameters so we have just {parameter} instead of {parameter?}
        regexReplace(expression: optionalParameterPattern, replacement: "(?:$1{$2})?", target: compiled)
        
        // Compile captures since unfortunately Foundation doesnt’t support named groups
        var captures = Array<String>()
        
        self.parameterPattern.enumerateMatches(in: String(compiled), options: [], range: NSMakeRange(0, compiled.length)) { (match, _, _) in
            if let match = match, match.numberOfRanges > 1 {
                let range = match.rangeAt(1)
                
                if range.location != NSNotFound {
                    captures.append(compiled.substring(with: range))
                }
            }
        }
        
        for alias in self.aliases {
            compiled.replaceOccurrences(of: "{\(alias.0)}", with: "(\(alias.1))", options: [], range: NSMakeRange(0, compiled.length))
        }
        
        regexReplace(expression: self.parameterPattern, replacement: "([^\\/]+)", target: compiled)
        compiled.insert("^", at: 0)
        compiled.append("$")
        
        do {
            let expression = try NSRegularExpression(pattern: String(compiled), options: [])
            return CompiledPattern(expression, captures)
        } catch let error as NSError {
            fatalError("Error compiling pattern: \(compiled), error: \(error)")
        }
    }
    
    /**
     Route a URL and get the routed instance back
     
     - parameter url: URL string to route
     
     - returns: Instance of SHNUrlRouted with binded parameters if matched, nil if route isn’t supported
     */
    public func route(for url: String) -> SHNUrlRouted? {
        if let url = URL(string: url) {
            return self.route(for: url)
        } else {
            return nil
        }
    }
    
    /**
     Route a URL and get the routed instance back
     
     - parameter url: URL to route
     
     - returns: Instance of SHNUrlRouted with binded parameters if matched, nil if route isn’t supported
     */
    public func route(for url: URL) -> SHNUrlRouted? {
        let path = self.normalizePath(path: url.path)
        let range = NSMakeRange(0, path.characters.count)
        
        for pattern in patterns {
            if let match = pattern.0.0.firstMatch(in: path, options: [], range: range) {
                var parameters = Dictionary<String, String>()
                let parameterKeys = pattern.0.1
                
                if parameterKeys.count > 0 {
                    for i in 1 ..< match.numberOfRanges {
                        let range = match.rangeAt(i)
                        
                        if range.location != NSNotFound {
                            let value = (path as NSString).substring(with: range)
                            
                            if i <= parameterKeys.count {
                                parameters[parameterKeys[i - 1]] = value
                            }
                        }
                    }
                }
                
                return SHNUrlRouted(route: pattern.1, parameters: parameters)
            }
        }
        
        return nil
    }
    
    /**
     Dispatch a url
     
     - parameter url: URL string to dispatch
     
     - returns: True if dispatched, false if unable to dispatch which occurs if url isn’t routable
     */
    public func dispatch(for url: String) -> RouteResult {
        if let url = URL(string: url) {
            return self.dispatch(for: url)
        } else {
            return RouteResult.failed
        }
    }
    
    /**
     Dispatch a url
     
     - parameter url: URL to dispatch
     
     - returns: True if dispatched, false if unable to dispatch which occurs if url isn’t routable
     */
    public func dispatch(for url: URL) -> RouteResult {
        if let routed = self.route(for: url) {
            if let output = routed.route.handler(url, routed.route, routed.parameters) {
                return output
            }
            return RouteResult.succeeded
        } else {
            return RouteResult.failed
        }
    }
    
}
