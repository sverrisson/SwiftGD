#if os(Linux)
	import Glibc
	import Cgdlinux
#else
	import Darwin
	import Cgdmac
#endif

import Foundation

public class Image {

	private var internalImage: gdImagePtr

	public var size: (width: Int, height: Int) {
		return (width: Int(internalImage.pointee.sx), height: Int(internalImage.pointee.sy))
	}

	public init?(width: Int, height: Int) {
		internalImage = gdImageCreateTrueColor(Int32(width), Int32(height))
	}

	public init?(url: URL) {
		let inputFile = fopen(url.path, "rb")
		defer { fclose(inputFile) }

		guard inputFile != nil else { return nil }

		let loadedImage: gdImagePtr?

		if url.lastPathComponent.hasSuffix("jpg") || url.lastPathComponent.hasSuffix("jpeg") {
			loadedImage = gdImageCreateFromJpeg(inputFile)
		} else if url.lastPathComponent.hasSuffix("png") {
			loadedImage = gdImageCreateFromPng(inputFile)
		} else {
			return nil
		}

		if let image = loadedImage {
			internalImage = image
		} else {
			return nil
		}
	}
    
    public init?(path: String, callback: (String?) -> ()) {
        let imageURL = URL(fileURLWithPath: path)
        print("Imagepath: \(imageURL)")
        
        guard let data = try? Data(contentsOf: imageURL) else { return nil }
        var mutData = data
        self.internalImage = mutData.withUnsafeMutableBytes {
            (data) -> UnsafeMutablePointer<gdImage> in
            return data.pointee
        }
        callback(self.base64())
    }
    
    public func base64(quality: Int32 = 67) -> String? {
        var size: Int32 = 0
        if let image = gdImageJpegPtr(internalImage, &size, quality) {
            // gdImageJpegPtr returns an UnsafeMutableRawPointer that is converted to a Data object
            let d = Data(bytesNoCopy: image, count: Int(size), deallocator: Data.Deallocator.free)
            return d.base64EncodedString()
        }
        return nil
    }

	private init(gdImage: gdImagePtr) {
		self.internalImage = gdImage
	}

	@discardableResult
	public func write(to url: URL, quality: Int = 100) -> Bool {
		let fileType = url.pathExtension
		guard fileType == "png" || fileType == "jpeg" || fileType == "jpg" else { return false }

		let fm = FileManager()

		// refuse to overwrite existing files
		guard fm.fileExists(atPath: url.path) == false else { return false }

		// open our output file, then defer it to close
		let outputFile = fopen(url.path, "wb")
		defer { fclose(outputFile) }

		// write the correct output format based on the path extension


		switch fileType {
			case "png":
				gdImageSaveAlpha(internalImage, 1)
				gdImagePng(internalImage, outputFile)
			case "jpg":
				fallthrough
			case "jpeg":
				gdImageJpeg(internalImage, outputFile, Int32(quality))
			default:
				return false
		}

		// return true or false based on whether the output file now exists
		return fm.fileExists(atPath: url.path)
	}

	public func resizedTo(width: Int, height: Int, applySmoothing: Bool = true) -> Image? {
		if applySmoothing {
			gdImageSetInterpolationMethod(internalImage, GD_BILINEAR_FIXED)
		} else {
			gdImageSetInterpolationMethod(internalImage, GD_NEAREST_NEIGHBOUR)
		}

		guard let output = gdImageScale(internalImage, UInt32(width), UInt32(height)) else { return nil }
		return Image(gdImage: output)
	}

	public func resizedTo(width: Int, applySmoothing: Bool = true) -> Image? {
		if applySmoothing {
			gdImageSetInterpolationMethod(internalImage, GD_BILINEAR_FIXED)
		} else {
			gdImageSetInterpolationMethod(internalImage, GD_NEAREST_NEIGHBOUR)
		}

		let currentSize = size
		let heightAdjustment = Double(width) / Double(currentSize.width)
		let newHeight = Double(currentSize.height) * Double(heightAdjustment)

		guard let output = gdImageScale(internalImage, UInt32(width), UInt32(newHeight)) else { return nil }
		return Image(gdImage: output)
	}

	public func resizedTo(height: Int, applySmoothing: Bool = true) -> Image? {
		if applySmoothing {
			gdImageSetInterpolationMethod(internalImage, GD_BILINEAR_FIXED)
		} else {
			gdImageSetInterpolationMethod(internalImage, GD_NEAREST_NEIGHBOUR)
		}

		let currentSize = size
		let widthAdjustment = Double(height) / Double(currentSize.height)
		let newWidth = Double(currentSize.width) * Double(widthAdjustment)

		guard let output = gdImageScale(internalImage, UInt32(newWidth), UInt32(height)) else { return nil }
		return Image(gdImage: output)
	}

	deinit {
		// always destroy our internal image resource
		gdImageDestroy(internalImage)
	}
}

public struct Size {
	var width: Int
	var height: Int

	public init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}
}
