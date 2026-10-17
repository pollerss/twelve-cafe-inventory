-- THE TWELVE CAFE v3: add selectable reasons for restock requests.
-- Run only after upgrade_v2.sql. Existing items, counts and history are unchanged.
BEGIN;
ALTER TABLE public.restock_requests ADD COLUMN IF NOT EXISTS reason_code text;
ALTER TABLE public.restock_requests ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.restock_requests ADD CONSTRAINT restock_reason_code_allowed_v3
  CHECK (reason_code IS NULL OR reason_code IN
   ('LOW_STOCK','OUT_OF_STOCK','EXPECTED_DEMAND','ROUTINE_REPLENISHMENT','REPLACEMENT','OTHER'));
COMMIT;
