import 'balance.dart';

class TableOrder {
  const TableOrder(
    this.products, {
    this.step = 1,
    this.gatheredProducts = const [],
  });

  final List<Goods> products;
  final int step;
  final List<Goods> gatheredProducts;

  int get gathered => gatheredProducts.length;

  int requested(Goods product) =>
      products.where((item) => item == product).length;

  int gatheredCount(Goods product) =>
      gatheredProducts.where((item) => item == product).length;

  bool needs(Goods product) => gatheredCount(product) < requested(product);

  Tool next(OrderRules rules) => rules.steps[step];

  TableOrder gather(OrderRules rules, Goods product) {
    if (next(rules) != Tool.gather || !needs(product)) return this;
    final collected = List<Goods>.unmodifiable([...gatheredProducts, product]);
    return TableOrder(
      products,
      step: collected.length == products.length ? step + 1 : step,
      gatheredProducts: collected,
    );
  }

  TableOrder advance(OrderRules rules) => next(rules) == Tool.gather
      ? this
      : TableOrder(
          products,
          step: step + 1,
          gatheredProducts: gatheredProducts,
        );

  TableOrder setback(OrderRules rules) {
    final gather = rules.steps.indexOf(Tool.gather);
    final weigh = rules.steps.indexOf(Tool.weigh);
    if (rules.setback == OrderSetback.rewind && step > weigh) {
      return TableOrder(
        products,
        step: weigh,
        gatheredProducts: gatheredProducts,
      );
    }
    return TableOrder(
      products,
      step: gather,
      gatheredProducts: List<Goods>.unmodifiable(
        gatheredProducts.take(gathered - 1),
      ),
    );
  }
}
