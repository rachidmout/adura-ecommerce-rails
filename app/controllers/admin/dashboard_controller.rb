module Admin
  class DashboardController < BaseController
    PERIODS = [ 7, 30 ].freeze

    def show
      @period = PERIODS.include?(params[:period].to_i) ? params[:period].to_i : 30

      load_kpis
      load_sales_chart
      load_lists
      load_promo_codes
      load_reviews
    end

    private

    def load_kpis
      @total_revenue_cents = Order.completed.sum(:total_cents)
      @month_revenue_cents = Order.completed.where(paid_at: Time.current.beginning_of_month..).sum(:total_cents)
      @order_count = Order.completed.count
      @month_order_count = Order.completed.where(paid_at: Time.current.beginning_of_month..).count
      @average_order_cents = @order_count.positive? ? @total_revenue_cents / @order_count : 0
      @published_count = Product.published.count
      @low_stock_count = ProductVariant.active.low_stock.count
      # Commandes payées qui ne sont pas encore expédiées. Une commande en
      # préparation reste donc visible dans la charge opérationnelle, tout en
      # restant distincte d'une commande déjà remise au transporteur.
      @pending_orders_count = Order.awaiting_shipment.count
      @shipped_orders_count = Order.shipped.count
    end

    def load_sales_chart
      range = (@period - 1).days.ago.to_date..Date.current
      orders_in_range = Order.completed.where(paid_at: range.first.beginning_of_day..range.last.end_of_day)
      totals_by_day = orders_in_range.each_with_object(Hash.new(0)) { |order, totals| totals[order.paid_at.to_date] += order.total_cents }
      @daily_sales = range.map { |date| [ date, totals_by_day[date] ] }
    end

    def load_lists
      @recent_orders = Order.order(created_at: :desc).limit(8)
      @low_stock_variants = ProductVariant.active.low_stock.includes(:product).order(Arel.sql("stock_quantity - reserved_stock_quantity")).limit(8)
      @top_products = OrderItem.joins(:order).merge(Order.completed)
                                .group(:brand_name, :product_name)
                                .sum(:quantity)
                                .sort_by { |_names, quantity| -quantity }
                                .first(5)
    end

    def load_promo_codes
      @active_promo_codes_count = PromoCode.active_now.count
      @month_discount_given_cents = Order.completed.where(paid_at: Time.current.beginning_of_month..).sum(:discount_cents)
      @top_promo_codes = PromoCode.order(created_at: :desc).limit(5)
    end

    def load_reviews
      @average_review_rating = Review.approved.average(:rating)
      @pending_reviews_count = Review.pending.count
      @recent_reviews = Review.includes(:product).recent.limit(5)
    end
  end
end
