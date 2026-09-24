import { application } from "controllers/application"
import MenuController from "controllers/menu_controller"
import VariantController from "controllers/variant_controller"
import LanguageSelectorController from "controllers/language_selector_controller"
import AutoSubmitController from "controllers/auto_submit_controller"
import ImagePreviewController from "controllers/image_preview_controller"
import FilterPanelController from "controllers/filter_panel_controller"
import CartQuantityController from "controllers/cart_quantity_controller"
import CheckoutSubmissionController from "controllers/checkout_submission_controller"
import AddressLookupController from "controllers/address_lookup_controller"
import ShippingMethodsController from "controllers/shipping_methods_controller"
import PickupPointController from "controllers/pickup_point_controller"
import QuizFamilyController from "controllers/quiz_family_controller"
import CookieConsentController from "controllers/cookie_consent_controller"
import EcommerceAnalyticsController from "controllers/ecommerce_analytics_controller"
import QuizAnalyticsController from "controllers/quiz_analytics_controller"
import CatalogAnalyticsController from "controllers/catalog_analytics_controller"

application.register("menu", MenuController)
application.register("variant", VariantController)
application.register("language-selector", LanguageSelectorController)
application.register("auto-submit", AutoSubmitController)
application.register("image-preview", ImagePreviewController)
application.register("filter-panel", FilterPanelController)
application.register("cart-quantity", CartQuantityController)
application.register("checkout-submission", CheckoutSubmissionController)
application.register("address-lookup", AddressLookupController)
application.register("shipping-methods", ShippingMethodsController)
application.register("pickup-point", PickupPointController)
application.register("quiz-family", QuizFamilyController)
application.register("cookie-consent", CookieConsentController)
application.register("ecommerce-analytics", EcommerceAnalyticsController)
application.register("quiz-analytics", QuizAnalyticsController)
application.register("catalog-analytics", CatalogAnalyticsController)
