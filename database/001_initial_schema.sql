-- ========================================
-- ShiftPilot データベース初期構築
-- Version 0.1
-- ========================================

-- 企業情報
CREATE TABLE IF NOT EXISTS public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    company_code TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 店舗情報
CREATE TABLE IF NOT EXISTS public.stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL
        REFERENCES public.companies(id),
    store_code TEXT NOT NULL,
    store_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(company_id, store_code)
);

-- 部門情報
CREATE TABLE IF NOT EXISTS public.departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL
        REFERENCES public.stores(id),
    department_code TEXT NOT NULL,
    department_name TEXT NOT NULL,
    shift_start_day INTEGER DEFAULT 1
        CHECK (shift_start_day BETWEEN 1 AND 31),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(store_id, department_code)
);

-- スタッフ情報
CREATE TABLE IF NOT EXISTS public.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    department_id UUID NOT NULL
        REFERENCES public.departments(id),

    -- 将来Supabase Authと紐付ける
    auth_user_id UUID UNIQUE
        REFERENCES auth.users(id),

    employee_number TEXT NOT NULL,
    staff_name TEXT NOT NULL,

    -- 雇用区分
    employment_type TEXT NOT NULL DEFAULT 'part_time'
        CHECK (employment_type IN (
            'part_time',
            'casual',
            'full_time'
        )),

    -- 店舗での役職
    job_role TEXT NOT NULL DEFAULT 'staff'
        CHECK (job_role IN (
            'staff',
            'leader',
            'manager',
            'supervisor'
        )),

    -- アプリの管理権限
    app_role TEXT NOT NULL DEFAULT 'staff'
        CHECK (app_role IN (
            'staff',
            'editor',
            'admin',
            'owner'
        )),

    has_key BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    joined_at DATE,
    left_at DATE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(department_id, employee_number)
);

-- 曜日別勤務契約
CREATE TABLE IF NOT EXISTS public.work_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    staff_id UUID NOT NULL
        REFERENCES public.staff(id),

    weekday INTEGER NOT NULL
        CHECK (weekday BETWEEN 0 AND 6),

    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    break_minutes INTEGER NOT NULL DEFAULT 0
        CHECK (break_minutes >= 0),

    valid_from DATE NOT NULL,
    valid_until DATE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CHECK (end_time > start_time),
    CHECK (
        valid_until IS NULL
        OR valid_until >= valid_from
    )
);

-- 月間シフト
CREATE TABLE IF NOT EXISTS public.shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    staff_id UUID NOT NULL
        REFERENCES public.staff(id),

    shift_date DATE NOT NULL,

    shift_status TEXT NOT NULL DEFAULT 'holiday'
        CHECK (shift_status IN (
            'work',
            'absence',
            'holiday',
            'paid_leave',
            'half_paid_leave',
            'unavailable',
            'available',
            'support'
        )),

    start_time TIME,
    end_time TIME,

    break_minutes INTEGER NOT NULL DEFAULT 0
        CHECK (break_minutes >= 0),

    -- 他部門応援先
    support_department TEXT,

    is_published BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(staff_id, shift_date),

    CHECK (
        start_time IS NULL
        OR end_time IS NULL
        OR end_time > start_time
    )
);

-- ========================================
-- セキュリティ設定
-- ========================================

-- 全テーブルでRLSを有効にする
ALTER TABLE public.companies
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.stores
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.departments
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.staff
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.work_contracts
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shifts
ENABLE ROW LEVEL SECURITY;

-- API利用者への権限を一旦取り消す
-- 認証とRLSポリシー完成後に必要分だけ許可する
REVOKE ALL ON TABLE
    public.companies,
    public.stores,
    public.departments,
    public.staff,
    public.work_contracts,
    public.shifts
FROM anon, authenticated;
