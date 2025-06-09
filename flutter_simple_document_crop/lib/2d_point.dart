class Point2d {
  final int x, y;
  const Point2d(this.x, this.y);

  @override
  bool operator ==(dynamic other) =>
      other is Point2d && other.x == x && other.y == y;
  @override
  int get hashCode => x.hashCode | y.hashCode;

  @override
  String toString() {
    return 'Point2d(x: $x, y: $y)';
  }
}
