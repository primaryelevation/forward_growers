import 'balance.dart';

class TableOrder {
  const TableOrder(this.products, {this.step = 1, this.gathered = 0});

  final List<Goods> products;
  final int step;
  final int gathered;

  Tool next(OrderRules rules) => rules.steps[step];

  TableOrder advance(OrderRules rules) {
    if (next(rules) == Tool.gather && gathered + 1 < products.length) {
      return TableOrder(products, step: step, gathered: gathered + 1);
    }
    return TableOrder(
      products,
      step: step + 1,
      gathered: next(rules) == Tool.gather ? products.length : gathered,
    );
  }

  TableOrder setback(OrderRules rules) {
    final gather = rules.steps.indexOf(Tool.gather);
    final weigh = rules.steps.indexOf(Tool.weigh);
    if (rules.setback == OrderSetback.rewind && step > weigh) {
      return TableOrder(products, step: weigh, gathered: gathered);
    }
    return TableOrder(products, step: gather, gathered: gathered - 1);
  }
}
