# Transcode any image to JPG image that's great for shrinking wallpapers
function img2jpg
    if test (count $argv) -eq 0 -o "$argv[1]" = --help
        echo "Usage: img2jpg <image> [magick options]"
        echo "Transcode any image to JPG image that's great for shrinking wallpapers"
        echo "Output: <image_basename>-optimized.jpg"
        return
    end
    set img $argv[1]
    set rest $argv[2..-1]
    magick $img $rest -quality 95 -strip (string replace -r '\..*$' '' $img)-optimized.jpg
end

# Transcode any image to JPG image that's great for sharing online without being too big
function img2jpg-small
    if test (count $argv) -eq 0 -o "$argv[1]" = --help
        echo "Usage: img2jpg-small <image> [magick options]"
        echo "Transcode any image to JPG image that's great for sharing online without being too big"
        echo "Resizes to max 1080px width, quality 95%"
        echo "Output: <image_basename>-optimized.jpg"
        return
    end
    set img $argv[1]
    set rest $argv[2..-1]
    magick $img $rest -resize 1080x\> -quality 95 -strip (string replace -r '\..*$' '' $img)-optimized.jpg
end

# Transcode any image to compressed-but-lossless PNG
function img2png
    if test (count $argv) -eq 0 -o "$argv[1]" = --help
        echo "Usage: img2png <image> [magick options]"
        echo "Transcode any image to compressed-but-lossless PNG"
        echo "Uses optimal PNG compression settings"
        echo "Output: <image_basename>-optimized.png"
        return
    end
    set img $argv[1]
    set rest $argv[2..-1]
    magick $img $rest -strip -define png:compression-filter=5 \
        -define png:compression-level=9 \
        -define png:compression-strategy=1 \
        -define png:exclude-chunk=all \
        (string replace -r '\..*$' '' $img)-optimized.png
end
