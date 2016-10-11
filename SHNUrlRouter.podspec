Pod::Spec.new do |s|
	s.name         = "SHNUrlRouter"
	s.version      = "2.0.0"
	s.summary      = "Simple Router for Swift"
	s.homepage     = "https://github.com/fanduel/SHNUrlRouter"
	s.license      = "MIT"

	s.author       = "Shaun Harrison"

	s.platform     = :ios, "9.0"

	s.source       = { :git => "https://github.com/fanduel/SHNUrlRouter.git", :tag => s.version }

	s.source_files = "*.swift"
	s.requires_arc = true
end