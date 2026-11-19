-- CreateEnum
CREATE TYPE "EventFormat" AS ENUM ('OFFLINE', 'ONLINE', 'HYBRID');

-- CreateEnum
CREATE TYPE "EventStatus" AS ENUM ('DRAFT', 'PENDING_REVIEW', 'REVISION_REQUESTED', 'APPROVED', 'PUBLISHED', 'REJECTED', 'SUSPENDED', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ModerationDecision" AS ENUM ('APPROVED', 'REVISION_REQUESTED', 'REJECTED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "EventPermission" AS ENUM ('VIEW_EVENT', 'VIEW_PARTICIPANTS', 'ASSIST_REGISTRATION', 'VIEW_ORDERS', 'SCAN_TICKET', 'CHECK_IN_TICKET', 'VIEW_SCAN_HISTORY', 'VIEW_REPORTS', 'EXPORT_PARTICIPANTS');

-- CreateEnum
CREATE TYPE "InvitationStatus" AS ENUM ('PENDING', 'ACCEPTED', 'EXPIRED', 'REVOKED');

-- CreateEnum
CREATE TYPE "RegistrationMethod" AS ENUM ('SELF_SERVICE', 'ASSISTED');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('PENDING_PAYMENT', 'PAID', 'EXPIRED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'PAID', 'EXPIRED', 'FAILED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('SIMULATED_VIRTUAL_ACCOUNT');

-- CreateEnum
CREATE TYPE "ScanResult" AS ENUM ('VALID', 'ALREADY_USED', 'INVALID', 'WRONG_EVENT', 'CANCELLED', 'REVOKED', 'PAYMENT_REQUIRED', 'NETWORK_ERROR');

-- CreateEnum
CREATE TYPE "CheckInSource" AS ENUM ('ONLINE', 'OFFLINE_SYNC');

-- CreateEnum
CREATE TYPE "EmailDeliveryStatus" AS ENUM ('PENDING', 'SENT', 'FAILED');

-- CreateEnum
CREATE TYPE "PlanStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('ACTIVE', 'PENDING_PAYMENT', 'EXPIRED', 'CANCELLED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "BillingInterval" AS ENUM ('MONTHLY', 'YEARLY');

-- CreateEnum
CREATE TYPE "ReportCategory" AS ENUM ('EVENT', 'PAYMENT', 'E_TICKET', 'REGISTRATION', 'ACCOUNT', 'SUBSCRIPTION', 'TRANSACTION', 'SCANNER', 'OTHER');

-- CreateEnum
CREATE TYPE "ReportStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'WAITING_FOR_USER', 'RESOLVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "ReportPriority" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'URGENT');

-- CreateEnum
CREATE TYPE "ReportActivityVisibility" AS ENUM ('PUBLIC', 'INTERNAL');

-- CreateTable
CREATE TABLE "profiles" (
    "id" UUID NOT NULL,
    "name" TEXT,
    "email" TEXT NOT NULL,
    "username" TEXT,
    "password_hash" TEXT,
    "role" TEXT NOT NULL,
    "avatar_url" TEXT,
    "disabled_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "organizer_profiles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "organization_name" TEXT,
    "contact_name" TEXT,
    "phone" TEXT,
    "website" TEXT,
    "description" TEXT,
    "logo_url" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "organizer_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_categories" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title" TEXT NOT NULL,
    "description" TEXT,
    "event_date" TIMESTAMPTZ(6),
    "end_date_time" TIMESTAMPTZ(6),
    "time_zone" TEXT,
    "location" TEXT,
    "online_url" TEXT,
    "event_format" "EventFormat" NOT NULL DEFAULT 'OFFLINE',
    "contact_info" TEXT,
    "organizer_name" TEXT,
    "public_info" TEXT,
    "attendee_fields" JSONB,
    "status" "EventStatus" NOT NULL DEFAULT 'DRAFT',
    "review_note" TEXT,
    "submitted_at" TIMESTAMPTZ(6),
    "is_public" BOOLEAN NOT NULL DEFAULT false,
    "public_url" TEXT,
    "registration_qr_url" TEXT,
    "total_tickets" INTEGER DEFAULT 0,
    "price" DECIMAL(14,2) DEFAULT 0,
    "created_by" UUID,
    "category_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_moderations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "admin_id" UUID NOT NULL,
    "decision" "ModerationDecision" NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_moderations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_members" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'staff',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_member_permissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_member_id" UUID NOT NULL,
    "permission" "EventPermission" NOT NULL,
    "granted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_member_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_invitations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "invited_by_id" UUID NOT NULL,
    "accepted_by_id" UUID,
    "email" VARCHAR(320) NOT NULL,
    "token_hash" TEXT NOT NULL,
    "status" "InvitationStatus" NOT NULL DEFAULT 'PENDING',
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "accepted_at" TIMESTAMPTZ(6),
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_invitations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_invitation_permissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_invitation_id" UUID NOT NULL,
    "permission" "EventPermission" NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_invitation_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ticket_types" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "price" DECIMAL(14,2) NOT NULL,
    "quota" INTEGER NOT NULL,
    "sold" INTEGER NOT NULL DEFAULT 0,
    "held" INTEGER NOT NULL DEFAULT 0,
    "max_per_order" INTEGER,
    "sales_start" TIMESTAMPTZ(6),
    "sales_end" TIMESTAMPTZ(6),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ticket_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_number" VARCHAR(64) NOT NULL,
    "event_id" UUID NOT NULL,
    "purchaser_id" UUID,
    "assisted_by_member_id" UUID,
    "registration_method" "RegistrationMethod" NOT NULL DEFAULT 'SELF_SERVICE',
    "guest_name" TEXT,
    "guest_email" VARCHAR(320),
    "guest_phone" VARCHAR(40),
    "status" "OrderStatus" NOT NULL DEFAULT 'PENDING_PAYMENT',
    "subtotal" DECIMAL(14,2) NOT NULL,
    "service_fee" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "commission_rate" DECIMAL(9,6) NOT NULL DEFAULT 0,
    "commission_amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "grand_total" DECIMAL(14,2) NOT NULL,
    "expires_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "ticket_type_id" UUID NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit_price" DECIMAL(14,2) NOT NULL,
    "subtotal" DECIMAL(14,2) NOT NULL,

    CONSTRAINT "order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attendees" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_item_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "email" VARCHAR(320),
    "phone" VARCHAR(40),
    "organization" TEXT,
    "custom_fields" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attendees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "method" "PaymentMethod" NOT NULL DEFAULT 'SIMULATED_VIRTUAL_ACCOUNT',
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "amount" DECIMAL(14,2) NOT NULL,
    "payment_reference" TEXT,
    "idempotency_key" TEXT,
    "virtual_account_number" TEXT,
    "virtual_account_bank" TEXT,
    "expires_at" TIMESTAMPTZ(6),
    "paid_at" TIMESTAMPTZ(6),
    "failure_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tickets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ticket_code" TEXT NOT NULL,
    "token_hash" TEXT,
    "event_id" UUID NOT NULL,
    "user_id" UUID,
    "ticket_type_id" UUID,
    "attendee_id" UUID,
    "qr_code_data" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "purchased_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "issued_at" TIMESTAMPTZ(6),
    "used_at" TIMESTAMPTZ(6),

    CONSTRAINT "tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scan_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "ticket_id" UUID,
    "scanned_by_user_id" UUID,
    "event_member_id" UUID,
    "client_scan_id" TEXT,
    "scanned_token_hash" TEXT,
    "result" "ScanResult" NOT NULL,
    "is_offline" BOOLEAN NOT NULL DEFAULT false,
    "scanned_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "scan_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "check_ins" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ticket_id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "actor_user_id" UUID NOT NULL,
    "event_member_id" UUID,
    "source" "CheckInSource" NOT NULL DEFAULT 'ONLINE',
    "checked_in_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "synced_at" TIMESTAMPTZ(6),
    "client_scan_id" TEXT,

    CONSTRAINT "check_ins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ticket_email_deliveries" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ticket_id" UUID NOT NULL,
    "recipient" VARCHAR(320) NOT NULL,
    "status" "EmailDeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "last_error" TEXT,
    "next_attempt_at" TIMESTAMPTZ(6),
    "sent_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ticket_email_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plans" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "description" TEXT,
    "status" "PlanStatus" NOT NULL DEFAULT 'ACTIVE',
    "is_free" BOOLEAN NOT NULL DEFAULT false,
    "price_monthly" DECIMAL(14,2),
    "price_yearly" DECIMAL(14,2),
    "max_active_events" INTEGER,
    "max_tickets_per_event" INTEGER,
    "max_staff_per_event" INTEGER,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plan_features" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "plan_id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plan_features_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organizer_id" UUID NOT NULL,
    "plan_id" UUID NOT NULL,
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "billing_interval" "BillingInterval",
    "starts_at" TIMESTAMPTZ(6) NOT NULL,
    "ends_at" TIMESTAMPTZ(6) NOT NULL,
    "auto_renew" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscription_history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "subscription_id" UUID NOT NULL,
    "from_plan_id" UUID,
    "to_plan_id" UUID,
    "changed_by_id" UUID,
    "reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "subscription_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscription_payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "subscription_id" UUID NOT NULL,
    "invoice_number" VARCHAR(64) NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "method" TEXT NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "payment_reference" TEXT,
    "paid_at" TIMESTAMPTZ(6),
    "expires_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "subscription_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "platform_transactions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_payment_id" UUID,
    "subscription_payment_id" UUID,
    "gross_amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "commission_rate" DECIMAL(9,6) NOT NULL DEFAULT 0,
    "commission_amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "service_fee" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "platform_revenue" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "organizer_net_amount" DECIMAL(14,2),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "platform_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "support_reports" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ticket_number" VARCHAR(64) NOT NULL,
    "status_token_hash" TEXT NOT NULL,
    "reporter_id" UUID,
    "assigned_to_id" UUID,
    "order_id" UUID,
    "contact_email" VARCHAR(320),
    "order_reference" TEXT,
    "category" "ReportCategory" NOT NULL,
    "subject" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "status" "ReportStatus" NOT NULL DEFAULT 'OPEN',
    "priority" "ReportPriority" NOT NULL DEFAULT 'MEDIUM',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(6),

    CONSTRAINT "support_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "support_report_activities" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "report_id" UUID NOT NULL,
    "author_id" UUID,
    "author_name" TEXT,
    "visibility" "ReportActivityVisibility" NOT NULL DEFAULT 'PUBLIC',
    "action" TEXT NOT NULL,
    "message" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_report_activities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "platform_settings" (
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "platform_settings_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "platform_setting_history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "setting_key" TEXT NOT NULL,
    "old_value" JSONB,
    "new_value" JSONB NOT NULL,
    "changed_by_id" UUID,
    "reason" TEXT,
    "changed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "platform_setting_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "actor_id" UUID,
    "actor_name" TEXT,
    "actor_role" TEXT,
    "action" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "reason" TEXT,
    "details" TEXT,
    "metadata" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_activity_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "actor_id" UUID,
    "actor_name" TEXT,
    "action" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "metadata" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_activity_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "category" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "target_url" TEXT,
    "metadata" JSONB,
    "read_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "revoked_tokens" (
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "revoked_tokens_pkey" PRIMARY KEY ("token_hash")
);

-- CreateIndex
CREATE UNIQUE INDEX "profiles_email_key" ON "profiles"("email");

-- CreateIndex
CREATE INDEX "profiles_role_idx" ON "profiles"("role");

-- CreateIndex
CREATE UNIQUE INDEX "organizer_profiles_user_id_key" ON "organizer_profiles"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "event_categories_name_key" ON "event_categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "event_categories_slug_key" ON "event_categories"("slug");

-- CreateIndex
CREATE INDEX "events_created_by_idx" ON "events"("created_by");

-- CreateIndex
CREATE INDEX "events_category_id_idx" ON "events"("category_id");

-- CreateIndex
CREATE INDEX "events_status_event_date_idx" ON "events"("status", "event_date");

-- CreateIndex
CREATE INDEX "event_moderations_event_id_created_at_idx" ON "event_moderations"("event_id", "created_at");

-- CreateIndex
CREATE INDEX "event_moderations_admin_id_created_at_idx" ON "event_moderations"("admin_id", "created_at");

-- CreateIndex
CREATE INDEX "event_members_user_id_idx" ON "event_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "event_members_event_user_unique" ON "event_members"("event_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "event_member_permissions_event_member_id_permission_key" ON "event_member_permissions"("event_member_id", "permission");

-- CreateIndex
CREATE UNIQUE INDEX "event_invitations_token_hash_key" ON "event_invitations"("token_hash");

-- CreateIndex
CREATE INDEX "event_invitations_event_id_status_expires_at_idx" ON "event_invitations"("event_id", "status", "expires_at");

-- CreateIndex
CREATE INDEX "event_invitations_email_status_idx" ON "event_invitations"("email", "status");

-- CreateIndex
CREATE UNIQUE INDEX "event_invitation_permissions_event_invitation_id_permission_key" ON "event_invitation_permissions"("event_invitation_id", "permission");

-- CreateIndex
CREATE INDEX "ticket_types_event_id_is_active_sales_start_sales_end_idx" ON "ticket_types"("event_id", "is_active", "sales_start", "sales_end");

-- CreateIndex
CREATE UNIQUE INDEX "ticket_types_event_id_name_key" ON "ticket_types"("event_id", "name");

-- CreateIndex
CREATE UNIQUE INDEX "event_orders_order_number_key" ON "event_orders"("order_number");

-- CreateIndex
CREATE INDEX "event_orders_event_id_status_created_at_idx" ON "event_orders"("event_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "event_orders_purchaser_id_created_at_idx" ON "event_orders"("purchaser_id", "created_at");

-- CreateIndex
CREATE INDEX "event_orders_assisted_by_member_id_idx" ON "event_orders"("assisted_by_member_id");

-- CreateIndex
CREATE INDEX "order_items_ticket_type_id_idx" ON "order_items"("ticket_type_id");

-- CreateIndex
CREATE UNIQUE INDEX "order_items_order_id_ticket_type_id_key" ON "order_items"("order_id", "ticket_type_id");

-- CreateIndex
CREATE INDEX "attendees_order_item_id_idx" ON "attendees"("order_item_id");

-- CreateIndex
CREATE UNIQUE INDEX "order_payments_payment_reference_key" ON "order_payments"("payment_reference");

-- CreateIndex
CREATE UNIQUE INDEX "order_payments_idempotency_key_key" ON "order_payments"("idempotency_key");

-- CreateIndex
CREATE INDEX "order_payments_order_id_status_idx" ON "order_payments"("order_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "tickets_ticket_code_key" ON "tickets"("ticket_code");

-- CreateIndex
CREATE UNIQUE INDEX "tickets_token_hash_key" ON "tickets"("token_hash");

-- CreateIndex
CREATE UNIQUE INDEX "tickets_attendee_id_key" ON "tickets"("attendee_id");

-- CreateIndex
CREATE INDEX "tickets_event_id_status_idx" ON "tickets"("event_id", "status");

-- CreateIndex
CREATE INDEX "tickets_user_id_purchased_at_idx" ON "tickets"("user_id", "purchased_at");

-- CreateIndex
CREATE INDEX "scan_logs_event_id_scanned_at_idx" ON "scan_logs"("event_id", "scanned_at");

-- CreateIndex
CREATE INDEX "scan_logs_ticket_id_scanned_at_idx" ON "scan_logs"("ticket_id", "scanned_at");

-- CreateIndex
CREATE INDEX "scan_logs_result_scanned_at_idx" ON "scan_logs"("result", "scanned_at");

-- CreateIndex
CREATE UNIQUE INDEX "scan_logs_event_id_client_scan_id_key" ON "scan_logs"("event_id", "client_scan_id");

-- CreateIndex
CREATE UNIQUE INDEX "check_ins_ticket_id_key" ON "check_ins"("ticket_id");

-- CreateIndex
CREATE INDEX "check_ins_event_id_checked_in_at_idx" ON "check_ins"("event_id", "checked_in_at");

-- CreateIndex
CREATE UNIQUE INDEX "check_ins_event_id_client_scan_id_key" ON "check_ins"("event_id", "client_scan_id");

-- CreateIndex
CREATE INDEX "ticket_email_deliveries_status_next_attempt_at_idx" ON "ticket_email_deliveries"("status", "next_attempt_at");

-- CreateIndex
CREATE INDEX "ticket_email_deliveries_ticket_id_created_at_idx" ON "ticket_email_deliveries"("ticket_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "plans_name_key" ON "plans"("name");

-- CreateIndex
CREATE INDEX "plans_status_idx" ON "plans"("status");

-- CreateIndex
CREATE UNIQUE INDEX "plan_features_plan_id_key_key" ON "plan_features"("plan_id", "key");

-- CreateIndex
CREATE INDEX "subscriptions_organizer_id_status_ends_at_idx" ON "subscriptions"("organizer_id", "status", "ends_at");

-- CreateIndex
CREATE INDEX "subscriptions_plan_id_status_idx" ON "subscriptions"("plan_id", "status");

-- CreateIndex
CREATE INDEX "subscription_history_subscription_id_created_at_idx" ON "subscription_history"("subscription_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "subscription_payments_invoice_number_key" ON "subscription_payments"("invoice_number");

-- CreateIndex
CREATE UNIQUE INDEX "subscription_payments_payment_reference_key" ON "subscription_payments"("payment_reference");

-- CreateIndex
CREATE INDEX "subscription_payments_subscription_id_status_idx" ON "subscription_payments"("subscription_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "platform_transactions_order_payment_id_key" ON "platform_transactions"("order_payment_id");

-- CreateIndex
CREATE UNIQUE INDEX "platform_transactions_subscription_payment_id_key" ON "platform_transactions"("subscription_payment_id");

-- CreateIndex
CREATE INDEX "platform_transactions_created_at_idx" ON "platform_transactions"("created_at");

-- CreateIndex
CREATE UNIQUE INDEX "support_reports_ticket_number_key" ON "support_reports"("ticket_number");

-- CreateIndex
CREATE UNIQUE INDEX "support_reports_status_token_hash_key" ON "support_reports"("status_token_hash");

-- CreateIndex
CREATE INDEX "support_reports_status_priority_created_at_idx" ON "support_reports"("status", "priority", "created_at");

-- CreateIndex
CREATE INDEX "support_reports_reporter_id_created_at_idx" ON "support_reports"("reporter_id", "created_at");

-- CreateIndex
CREATE INDEX "support_reports_assigned_to_id_status_idx" ON "support_reports"("assigned_to_id", "status");

-- CreateIndex
CREATE INDEX "support_report_activities_report_id_created_at_idx" ON "support_report_activities"("report_id", "created_at");

-- CreateIndex
CREATE INDEX "support_report_activities_visibility_created_at_idx" ON "support_report_activities"("visibility", "created_at");

-- CreateIndex
CREATE INDEX "platform_setting_history_setting_key_changed_at_idx" ON "platform_setting_history"("setting_key", "changed_at");

-- CreateIndex
CREATE INDEX "audit_logs_created_at_idx" ON "audit_logs"("created_at");

-- CreateIndex
CREATE INDEX "audit_logs_actor_id_created_at_idx" ON "audit_logs"("actor_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_entity_type_entity_id_created_at_idx" ON "audit_logs"("entity_type", "entity_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_action_created_at_idx" ON "audit_logs"("action", "created_at");

-- CreateIndex
CREATE INDEX "event_activity_logs_event_id_created_at_idx" ON "event_activity_logs"("event_id", "created_at");

-- CreateIndex
CREATE INDEX "event_activity_logs_actor_id_created_at_idx" ON "event_activity_logs"("actor_id", "created_at");

-- CreateIndex
CREATE INDEX "notifications_user_id_read_at_created_at_idx" ON "notifications"("user_id", "read_at", "created_at");

-- CreateIndex
CREATE INDEX "revoked_tokens_expires_at_idx" ON "revoked_tokens"("expires_at");

-- AddForeignKey
ALTER TABLE "organizer_profiles" ADD CONSTRAINT "organizer_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "event_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_moderations" ADD CONSTRAINT "event_moderations_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_moderations" ADD CONSTRAINT "event_moderations_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_members" ADD CONSTRAINT "event_members_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_members" ADD CONSTRAINT "event_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_member_permissions" ADD CONSTRAINT "event_member_permissions_event_member_id_fkey" FOREIGN KEY ("event_member_id") REFERENCES "event_members"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_invitations" ADD CONSTRAINT "event_invitations_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_invitations" ADD CONSTRAINT "event_invitations_invited_by_id_fkey" FOREIGN KEY ("invited_by_id") REFERENCES "profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_invitations" ADD CONSTRAINT "event_invitations_accepted_by_id_fkey" FOREIGN KEY ("accepted_by_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_invitation_permissions" ADD CONSTRAINT "event_invitation_permissions_event_invitation_id_fkey" FOREIGN KEY ("event_invitation_id") REFERENCES "event_invitations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ticket_types" ADD CONSTRAINT "ticket_types_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_orders" ADD CONSTRAINT "event_orders_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_orders" ADD CONSTRAINT "event_orders_purchaser_id_fkey" FOREIGN KEY ("purchaser_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_orders" ADD CONSTRAINT "event_orders_assisted_by_member_id_fkey" FOREIGN KEY ("assisted_by_member_id") REFERENCES "event_members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "event_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_ticket_type_id_fkey" FOREIGN KEY ("ticket_type_id") REFERENCES "ticket_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendees" ADD CONSTRAINT "attendees_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "order_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_payments" ADD CONSTRAINT "order_payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "event_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_ticket_type_id_fkey" FOREIGN KEY ("ticket_type_id") REFERENCES "ticket_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_attendee_id_fkey" FOREIGN KEY ("attendee_id") REFERENCES "attendees"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scan_logs" ADD CONSTRAINT "scan_logs_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scan_logs" ADD CONSTRAINT "scan_logs_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "tickets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scan_logs" ADD CONSTRAINT "scan_logs_scanned_by_user_id_fkey" FOREIGN KEY ("scanned_by_user_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scan_logs" ADD CONSTRAINT "scan_logs_event_member_id_fkey" FOREIGN KEY ("event_member_id") REFERENCES "event_members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "check_ins" ADD CONSTRAINT "check_ins_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "tickets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "check_ins" ADD CONSTRAINT "check_ins_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "check_ins" ADD CONSTRAINT "check_ins_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "check_ins" ADD CONSTRAINT "check_ins_event_member_id_fkey" FOREIGN KEY ("event_member_id") REFERENCES "event_members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ticket_email_deliveries" ADD CONSTRAINT "ticket_email_deliveries_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "tickets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_features" ADD CONSTRAINT "plan_features_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_organizer_id_fkey" FOREIGN KEY ("organizer_id") REFERENCES "profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscription_history" ADD CONSTRAINT "subscription_history_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "subscriptions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscription_history" ADD CONSTRAINT "subscription_history_from_plan_id_fkey" FOREIGN KEY ("from_plan_id") REFERENCES "plans"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscription_history" ADD CONSTRAINT "subscription_history_to_plan_id_fkey" FOREIGN KEY ("to_plan_id") REFERENCES "plans"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscription_history" ADD CONSTRAINT "subscription_history_changed_by_id_fkey" FOREIGN KEY ("changed_by_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscription_payments" ADD CONSTRAINT "subscription_payments_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "subscriptions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "platform_transactions" ADD CONSTRAINT "platform_transactions_order_payment_id_fkey" FOREIGN KEY ("order_payment_id") REFERENCES "order_payments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "platform_transactions" ADD CONSTRAINT "platform_transactions_subscription_payment_id_fkey" FOREIGN KEY ("subscription_payment_id") REFERENCES "subscription_payments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_reports" ADD CONSTRAINT "support_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_reports" ADD CONSTRAINT "support_reports_assigned_to_id_fkey" FOREIGN KEY ("assigned_to_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_reports" ADD CONSTRAINT "support_reports_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "event_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_report_activities" ADD CONSTRAINT "support_report_activities_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "support_reports"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_report_activities" ADD CONSTRAINT "support_report_activities_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "platform_setting_history" ADD CONSTRAINT "platform_setting_history_setting_key_fkey" FOREIGN KEY ("setting_key") REFERENCES "platform_settings"("key") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "platform_setting_history" ADD CONSTRAINT "platform_setting_history_changed_by_id_fkey" FOREIGN KEY ("changed_by_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_activity_logs" ADD CONSTRAINT "event_activity_logs_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_activity_logs" ADD CONSTRAINT "event_activity_logs_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
