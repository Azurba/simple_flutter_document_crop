import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_simple_document_crop/2d_point.dart';
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';

class CropService {
  Future<void> processAndTrimImage(String sourceAssetPath) async {
    final rawImageData = File(sourceAssetPath).readAsBytesSync();
    final baseVisualRepresentation = decodeImage(rawImageData);

    if (baseVisualRepresentation == null) {
      print('Failed to decode initial image data from: $sourceAssetPath');
      return;
    }
    await _cannyAlgorithm(baseVisualRepresentation);

    final temporaryWorkArea = await getTemporaryDirectory();
    final edgeFeatureMapPath =
        '${temporaryWorkArea.path}/feature_map_visual.png';
    File(edgeFeatureMapPath)
        .writeAsBytesSync(encodePng(baseVisualRepresentation));
    print('Edge feature map saved to: $edgeFeatureMapPath');

    await _extractDocument(edgeFeatureMapPath, sourceAssetPath);
  }

  Future<void> _extractDocument(
      String featureMapPath, String originalAssetPath) async {
    final featureMapFile = File(featureMapPath);
    final featureMapRawBytes = await featureMapFile.readAsBytes();
    final featureMapImage = decodeImage(featureMapRawBytes);

    final originalFile = File(originalAssetPath);
    final originalRawBytes = await originalFile.readAsBytes();
    final originalVisual = decodeImage(originalRawBytes);

    if (featureMapImage == null || originalVisual == null) {
      print('Failed to interpret required image data for trimming.');
      return;
    }

    final imageWidth = featureMapImage.width;
    final imageHeight = featureMapImage.height;
    final centralHorizontalPoint = imageWidth ~/ 2;
    final centralVerticalPoint = imageHeight ~/ 2;

    int? boundaryX1, boundaryX2, boundaryY1, boundaryY2;
    const int trimOverlapPixels = 3;

    bool isProminentEdge(Pixel px) =>
        px.r > 12 && px.g > 12 && px.b > 12 && px.a > 12;

    final horizontalScanBuffer = (imageWidth * 0.025).toInt();
    final verticalScanBuffer = (imageHeight * 0.025).toInt();

    for (int x = horizontalScanBuffer; x <= centralHorizontalPoint; x++) {
      if (isProminentEdge(featureMapImage.getPixel(x, centralVerticalPoint))) {
        boundaryX1 = x;
        break;
      }
    }
    for (int x = imageWidth - 1 - horizontalScanBuffer;
        x >= centralHorizontalPoint;
        x--) {
      if (isProminentEdge(featureMapImage.getPixel(x, centralVerticalPoint))) {
        boundaryX2 = x;
        break;
      }
    }

    for (int y = verticalScanBuffer; y <= centralVerticalPoint; y++) {
      if (isProminentEdge(
          featureMapImage.getPixel(centralHorizontalPoint, y))) {
        boundaryY1 = y;
        break;
      }
    }
    for (int y = imageHeight - 1 - verticalScanBuffer;
        y >= centralVerticalPoint;
        y--) {
      if (isProminentEdge(
          featureMapImage.getPixel(centralHorizontalPoint, y))) {
        boundaryY2 = y;
        break;
      }
    }

    if ([boundaryX1, boundaryX2, boundaryY1, boundaryY2]
        .any((b) => b == null)) {
      print(
          'Automated boundary detection failed or was incomplete. Cropping aborted.');
      return;
    }

    final finalCropLeft =
        (boundaryX1! - trimOverlapPixels).clamp(0, imageWidth);
    final finalCropTop =
        (boundaryY1! - trimOverlapPixels).clamp(0, imageHeight);
    final finalCropRight =
        (boundaryX2! + trimOverlapPixels).clamp(0, imageWidth);
    final finalCropBottom =
        (boundaryY2! + trimOverlapPixels).clamp(0, imageHeight);

    final croppedImage = copyCrop(
      originalVisual,
      x: finalCropLeft,
      y: finalCropTop,
      width: finalCropRight - finalCropLeft,
      height: finalCropBottom - finalCropTop,
    );

    final finalProcessedAssetPath =
        originalAssetPath.replaceFirst(RegExp(r'\.(\w+)$'), '_refined_doc.JPG');

    await File(finalProcessedAssetPath).writeAsBytes(encodePng(croppedImage));
    print(
        'Document trimming successful! Output saved to: $finalProcessedAssetPath');
  }

  Future<Set<Set<Point2d>>> _cannyAlgorithm(
    Image image, {
    int? blurRadius = 2,
    int? lowThreshold,
    int? highThreshold,
    void Function(Image image)? onGrayConvertion,
    void Function(Image image)? onBlur,
    void Function(Image image)? onSobel,
    void Function(Image image)? onNonMaxSuppressed,
    void Function(Image image)? onImageResult,
  }) async {
    grayscale(image);
    if (onGrayConvertion != null) onGrayConvertion(image);

    if (blurRadius != null) {
      gaussianBlur(image, radius: blurRadius);
      if (onBlur != null) onBlur(image);
    }

    Image sobel = Image(width: image.width, height: image.height);
    Image edgeDirection = Image(width: image.width, height: image.height);

    int clampX(int x, Image image) => x.clamp(0, image.width - 1).toInt();
    int clampY(int y, Image image) => y.clamp(0, image.height - 1).toInt();
    int clamp255(num p) => p.clamp(0, 255).toInt();

    int getSafe(int x, int y, Image image) {
      final pixel = image.getPixel(clampX(x, image), clampY(y, image));
      return pixel.getChannel(Channel.red).toInt();
    }

    for (var y = 0; y < image.height; ++y) {
      for (var x = 0; x < image.width; ++x) {
        int gx = -getSafe(x - 1, y - 1, image) -
            2 * getSafe(x - 1, y, image) -
            getSafe(x - 1, y + 1, image) +
            getSafe(x + 1, y - 1, image) +
            2 * getSafe(x + 1, y, image) +
            getSafe(x + 1, y + 1, image);
        int gy = -getSafe(x - 1, y + 1, image) -
            2 * getSafe(x, y + 1, image) -
            getSafe(x + 1, y + 1, image) +
            getSafe(x - 1, y - 1, image) +
            2 * getSafe(x, y - 1, image) +
            getSafe(x + 1, y - 1, image);
        int mag = clamp255(math.sqrt(gx * gx + gy * gy));
        sobel.setPixelRgba(x, y, mag, mag, mag, 255);
        double direction = math.atan2(gy, gx);
        direction = (direction + math.pi / 2) * 180 / math.pi;
        if (direction >= 22.5 && direction < 67.5) {
          edgeDirection.setPixel(x, y, ColorInt8.rgb(45, 45, 45));
        } else if (direction >= 67.5 && direction < 112.5) {
          edgeDirection.setPixel(x, y, ColorInt8.rgb(90, 90, 90));
        } else if (direction >= 112.5 && direction < 157.5) {
          edgeDirection.setPixel(x, y, ColorInt8.rgb(135, 135, 135));
        } else {
          edgeDirection.setPixel(x, y, ColorInt8.rgb(0, 0, 0));
        }
      }
    }
    if (onSobel != null) onSobel(sobel);

    getNeighbours(x, y) {
      int direction =
          edgeDirection.getPixel(x, y).getChannel(Channel.red).toInt();
      Set<Point2d> nei = {};
      switch (direction) {
        case 0:
          if (y > 0) nei.add(Point2d(x, y - 1));
          if (y < image.height - 1) nei.add(Point2d(x, y + 1));
          break;
        case 45:
          if (x > 0 && y > 0) nei.add(Point2d(x - 1, y - 1));
          if (x < image.width - 1 && y < image.height - 1)
            nei.add(Point2d(x + 1, y + 1));
          break;
        case 90:
          if (x > 0) nei.add(Point2d(x - 1, y));
          if (x < image.width - 1) nei.add(Point2d(x + 1, y));
          break;
        case 135:
          if (y > 0 && x < image.width - 1) nei.add(Point2d(x + 1, y - 1));
          if (x > 0 && y < image.height - 1) nei.add(Point2d(x - 1, y + 1));
          break;
      }
      return nei;
    }

    for (var y = 0; y < image.height; ++y) {
      for (var x = 0; x < image.width; ++x) {
        final p = sobel.getPixel(x, y).getChannel(Channel.red).toInt();
        final nei = getNeighbours(x, y);
        final max = nei.fold(p, (t, i) {
          final pnew = sobel.getPixel(i.x, i.y).getChannel(Channel.red).toInt();
          return t > pnew ? t : pnew;
        });

        if (max > p) {
          image.setPixelRgba(x, y, 0, 0, 0, 255);
        } else {
          image.setPixelRgba(x, y, p, p, p, 255);
        }
      }
    }

    if (onNonMaxSuppressed != null) onNonMaxSuppressed(image);

    if (lowThreshold == null && highThreshold == null) {
      highThreshold = _otsusMethod(image);
      lowThreshold = highThreshold ~/ 2;
    } else if (lowThreshold == null && highThreshold != null) {
      highThreshold = highThreshold.clamp(0, 255).toInt();
      lowThreshold = highThreshold ~/ 2;
    } else if (lowThreshold != null && highThreshold == null) {
      lowThreshold = lowThreshold.clamp(0, 255).toInt();
      highThreshold = (lowThreshold * 2).clamp(0, 255).toInt();
    } else {
      lowThreshold = lowThreshold!.clamp(0, 255).toInt();
      highThreshold = highThreshold!.clamp(0, 255).toInt();
      if (lowThreshold > highThreshold) lowThreshold = highThreshold;
    }

    isWeak(x, y) => getSafe(x, y, image) >= lowThreshold!;
    isStrong(x, y) => getSafe(x, y, image) >= highThreshold!;
    Set<Set<Point2d>> edges = {};
    Set<Point2d> nonEdges = {};
    int currentLabel = 2;
    ListQueue<Point2d> currentBlobNeighbours = ListQueue();
    Image labeledPixels = Image(width: image.width, height: image.height);

    for (var y = 0; y < image.height; ++y) {
      for (var x = 0; x < image.width; ++x) {
        if (!isWeak(x, y)) {
          labeledPixels.setPixel(x, y, ColorInt8.rgb(1, 1, 1));
          image.setPixelRgba(x, y, 0, 0, 0, 255);
          continue;
        }
        if (labeledPixels.getPixel(x, y) != 0) {
          continue;
        }
        currentBlobNeighbours.addLast(Point2d(x, y));
        bool isStrongEdge = false;
        Set<Point2d> currentEdge = {};
        while (currentBlobNeighbours.isNotEmpty) {
          Point2d w = currentBlobNeighbours.removeLast();
          currentEdge.add(w);
          if (isStrong(w.x, w.y)) {
            isStrongEdge = true;
          }
          labeledPixels.setPixel(
            w.x,
            w.y,
            ColorInt8.rgb(currentLabel, currentLabel, currentLabel),
          );

          Set<Point2d> symmetricNeighbours = {};
          symmetricNeighbours.addAll(getNeighbours(w.x, w.y));
          if (w.x > 0 &&
              w.y > 0 &&
              getNeighbours(w.x - 1, w.y - 1).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x - 1, w.y - 1));
          }
          if (w.y > 0 && getNeighbours(w.x, w.y - 1).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x, w.y - 1));
          }
          if (w.x < image.width - 1 &&
              w.y > 0 &&
              getNeighbours(w.x + 1, w.y - 1).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x + 1, w.y - 1));
          }
          if (w.x > 0 &&
              w.y < image.height - 1 &&
              getNeighbours(w.x - 1, w.y + 1).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x - 1, w.y + 1));
          }
          if (w.y < image.height - 1 &&
              getNeighbours(w.x, w.y + 1).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x, w.y + 1));
          }
          if (w.x < image.width - 1 &&
              w.y < image.height - 1 &&
              getNeighbours(w.x + 1, w.y + 1).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x + 1, w.y + 1));
          }
          if (w.x > 0 && getNeighbours(w.x - 1, w.y).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x - 1, w.y));
          }
          if (w.x < image.width - 1 &&
              getNeighbours(w.x + 1, w.y).contains(w)) {
            symmetricNeighbours.add(Point2d(w.x + 1, w.y));
          }
          for (var neighbour in symmetricNeighbours) {
            if (isWeak(neighbour.x, neighbour.x) &&
                labeledPixels.getPixel(neighbour.x, neighbour.y) == 0) {
              currentBlobNeighbours.add(neighbour);
            }
          }
        }
        if (isStrongEdge) {
          edges.add(currentEdge);
        } else {
          nonEdges.addAll(currentEdge);
        }
        currentLabel++;
      }
    }

    for (var w in nonEdges) {
      image.setPixelRgba(w.x, w.y, 0, 0, 0, 255);
    }

    if (onImageResult != null) onImageResult(image);

    return edges;
  }

  int _otsusMethod(Image image) {
    List<int> histogramm = List.filled(256, 0);
    for (var y = 0; y < image.height; ++y) {
      for (var x = 0; x < image.width; ++x) {
        histogramm[getLuminance(image.getPixel(x, y)).toInt()]++;
      }
    }
    final int imageDimension = image.width * image.height;

    int bestThreshold = 0;
    double maxBetweenClassVariance;

    for (var currentThreshold = 1; currentThreshold < 255; ++currentThreshold) {
      final int bakgroundSum =
          histogramm.sublist(0, currentThreshold).fold(0, (a, b) => a + b);
      final int foregroundSum = imageDimension - bakgroundSum;

      final double backgroundWeight = bakgroundSum / imageDimension;
      final double foregroundWeight = 1 - backgroundWeight;

      double backgroundMean = 0;
      for (var i = 0; i < currentThreshold; ++i)
        backgroundMean += i * histogramm[i];
      backgroundMean /= bakgroundSum;

      double foregroundMean = 0;
      for (var i = currentThreshold; i < 256; ++i)
        foregroundMean += i * histogramm[i];
      foregroundMean /= foregroundSum;

      final double currentBetweenClassVariance = backgroundWeight *
          foregroundWeight *
          math.pow(backgroundMean - foregroundMean, 2);
      bestThreshold = currentThreshold;
      maxBetweenClassVariance = currentBetweenClassVariance;
    }

    return bestThreshold;
  }
}
