module Admin
  class UpdateCatalogVariant
    def initialize(variant:, attributes:)
      @variant = variant
      @attributes = attributes
    end

    def call
      ProductVariant.transaction do
        variant = ProductVariant.lock.find(@variant.id)
        variant.assign_attributes(@attributes)

        if variant.stock_quantity < variant.reserved_stock_quantity
          variant.errors.add(:stock_quantity, "ne peut pas être inférieur au stock réservé (#{variant.reserved_stock_quantity})")
          raise ActiveRecord::RecordInvalid, variant
        end

        variant.save!
        variant
      end
    end
  end
end
