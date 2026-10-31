// ============================================================================
// LOCALLANCE SHARED TYPESCRIPT CONTRACT (FRONTEND + BACKEND LOCKED)
// ============================================================================

export type CityCluster =
  | 'Mohali - Phase 3B2 / 7 / 8B'
  | 'Chandigarh - Sector 17 / 35'
  | 'Kharar / Landran Student Hub'
  | 'Ludhiana'
  | 'Amritsar'
  | 'Jalandhar'
  | 'Patiala'
  | 'Bathinda';

export type CategorySlug =
  | 'video-editing'
  | 'graphic-design'
  | 'photography-videography'
  | 'social-media-content';

export type SkuCode =
  | 'SKU-VIDEO-01'
  | 'SKU-PHOTO-02'
  | 'SKU-BANNER-03'
  | 'CUSTOM-PROJECT';

export type ApprovalStatus = 'pending' | 'approved' | 'rejected';

export type RequestStatus = 'new' | 'matched' | 'completed' | 'cancelled';

export type MatchStatus =
  | 'proposed'
  | 'accepted'
  | 'proof_submitted'
  | 'completed'
  | 'cancelled';

export type UserRole = 'customer' | 'freelancer' | 'admin';

export interface Category {
  id: string;
  name: string;
  slug: CategorySlug;
  created_at?: string;
}

export interface ServiceSku {
  code: SkuCode;
  title: string;
  category_slug: CategorySlug;
  deliverable_spec: string;
  base_price_display: string;
  min_price_inr: number;
  turnaround_text: string;
  requires_onsite: boolean;
}

// Public & Full Creator Profile (email & whatsapp_number are omitted in public_freelancers view)
export interface FreelancerProfile {
  id: string;
  user_id?: string | null;
  full_name: string;
  slug: string;
  email?: string; // Only visible to Admin
  whatsapp_number?: string; // Only visible to Admin
  headline: string;
  bio: string;
  city_cluster: CityCluster;
  service_radius_km: number;
  starting_price: number;
  category_slugs: CategorySlug[];
  supported_sku_codes: SkuCode[];
  availability_slots: string;
  portfolio_links: string[];
  approval_status: ApprovalStatus;
  is_cohort_vetted: boolean;
  created_at: string;
  is_demo?: boolean; // Client-side flag for fallback demo records
}

export interface ProjectRequest {
  id: string;
  reference_code: string;
  customer_name: string;
  business_name?: string | null;
  customer_whatsapp: string;
  city_cluster: CityCluster;
  shoot_address?: string | null;
  sku_code: SkuCode;
  category_slug?: CategorySlug | null;
  preferred_freelancer_slug?: string | null;
  preferred_slot: string;
  budget_range: string;
  project_brief: string;
  status: RequestStatus;
  created_at: string;
}

export interface DispatchMatch {
  id: string;
  request_id: string;
  freelancer_id: string;
  agreed_amount_inr: number;
  status: MatchStatus;
  proof_of_work_url?: string | null;
  created_at: string;
  updated_at: string;
}