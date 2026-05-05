-- ============================================================================
-- FERTILIZER RECOMMENDATION SYSTEM - DATABASE SCHEMA
-- ============================================================================
-- Database: fertilizer_recommendation_system
-- Description: Mobile-based decision support system for fertilizer 
--              recommendation using rule-based approach for cacao and durian
--              smallholder farmers in Davao City
-- Version: 1.0
-- Created: 2026
-- ============================================================================

-- Create the database (optional, run separately if needed)
-- CREATE DATABASE fertilizer_recommendation_system;
-- \c fertilizer_recommendation_system;

-- Enable UUID extension if you want to use UUIDs instead of integers
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- MASTER TABLES
-- ============================================================================

-- CROP table: stores all crop types
CREATE TABLE crop (
    crop_id SERIAL PRIMARY KEY,
    crop_name VARCHAR(100) NOT NULL UNIQUE,
    scientific_name VARCHAR(150),
    crop_category VARCHAR(50),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE crop IS 'Master table storing all crop types supported by the system';
COMMENT ON COLUMN crop.crop_id IS 'Primary key, auto-incrementing identifier';
COMMENT ON COLUMN crop.crop_name IS 'Common name of the crop (e.g., Cacao, Durian)';
COMMENT ON COLUMN crop.scientific_name IS 'Scientific/botanical name';
COMMENT ON COLUMN crop.crop_category IS 'Category classification (e.g., Perennial, Annual)';
COMMENT ON COLUMN crop.is_active IS 'Flag indicating if crop is currently active in the system';

-- GROWTH_STAGE table: stores growth stages for each crop
CREATE TABLE growth_stage (
    stage_id SERIAL PRIMARY KEY,
    crop_id INTEGER NOT NULL,
    stage_name VARCHAR(100) NOT NULL,
    stage_order INTEGER NOT NULL,
    duration_days_min INTEGER,
    duration_days_max INTEGER,
    stage_description TEXT,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (crop_id) REFERENCES crop(crop_id) ON DELETE CASCADE,
    UNIQUE(crop_id, stage_name),
    UNIQUE(crop_id, stage_order)
);

COMMENT ON TABLE growth_stage IS 'Growth stages for each crop with duration ranges';
COMMENT ON COLUMN growth_stage.stage_order IS 'Sequential order of growth stages (1, 2, 3, ...)';
COMMENT ON COLUMN growth_stage.duration_days_min IS 'Minimum duration of this stage in days from planting';
COMMENT ON COLUMN growth_stage.duration_days_max IS 'Maximum duration of this stage in days from planting (NULL for ongoing maintenance)';

-- LOCATION_SOIL_PROFILE table: stores barangay-level soil data
CREATE TABLE location_soil_profile (
    profile_id SERIAL PRIMARY KEY,
    barangay_location VARCHAR(200) NOT NULL UNIQUE,
    soil_series VARCHAR(100),
    ph_min DECIMAL(3,1),
    ph_max DECIMAL(3,1),
    soil_texture VARCHAR(50),
    drainage VARCHAR(50),
    fertility_status VARCHAR(50),
    source_reference VARCHAR(255),
    confidence_level VARCHAR(50),
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (ph_min >= 0 AND ph_min <= 14),
    CHECK (ph_max >= 0 AND ph_max <= 14),
    CHECK (ph_min <= ph_max)
);

COMMENT ON TABLE location_soil_profile IS 'Barangay-level soil profile data for location-based pH estimation';
COMMENT ON COLUMN location_soil_profile.barangay_location IS 'Barangay name or location identifier';
COMMENT ON COLUMN location_soil_profile.soil_series IS 'Soil series classification from DA-BSWM';
COMMENT ON COLUMN location_soil_profile.ph_min IS 'Minimum pH value for this location';
COMMENT ON COLUMN location_soil_profile.ph_max IS 'Maximum pH value for this location';
COMMENT ON COLUMN location_soil_profile.source_reference IS 'Reference to source data (DA-BSWM maps, studies, etc.)';
COMMENT ON COLUMN location_soil_profile.confidence_level IS 'Data confidence level (High, Medium, Low)';

-- ============================================================================
-- CROP-RELATED TABLES
-- ============================================================================

-- CROP_SUITABILITY table: stores pH suitability ranges for each crop
CREATE TABLE crop_suitability (
    suitability_id SERIAL PRIMARY KEY,
    crop_id INTEGER NOT NULL,
    optimal_ph_min DECIMAL(3,1),
    optimal_ph_max DECIMAL(3,1),
    s1_ph_min DECIMAL(3,1),
    s1_ph_max DECIMAL(3,1),
    s2_ph_min DECIMAL(3,1),
    s2_ph_max DECIMAL(3,1),
    s3_ph_min DECIMAL(3,1),
    s3_ph_max DECIMAL(3,1),
    n_ph_min DECIMAL(3,1),
    n_ph_max DECIMAL(3,1),
    suitability_notes TEXT,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (crop_id) REFERENCES crop(crop_id) ON DELETE CASCADE,
    UNIQUE(crop_id),
    CHECK (optimal_ph_min >= 0 AND optimal_ph_min <= 14),
    CHECK (optimal_ph_max >= 0 AND optimal_ph_max <= 14)
);

COMMENT ON TABLE crop_suitability IS 'pH suitability ranges (S1/S2/S3/N) for each crop';
COMMENT ON COLUMN crop_suitability.optimal_ph_min IS 'Optimal pH range minimum';
COMMENT ON COLUMN crop_suitability.optimal_ph_max IS 'Optimal pH range maximum';
COMMENT ON COLUMN crop_suitability.s1_ph_min IS 'Highly suitable (S1) pH range minimum';
COMMENT ON COLUMN crop_suitability.s1_ph_max IS 'Highly suitable (S1) pH range maximum';
COMMENT ON COLUMN crop_suitability.s2_ph_min IS 'Moderately suitable (S2) pH range minimum';
COMMENT ON COLUMN crop_suitability.s2_ph_max IS 'Moderately suitable (S2) pH range maximum';
COMMENT ON COLUMN crop_suitability.s3_ph_min IS 'Marginally suitable (S3) pH range minimum';
COMMENT ON COLUMN crop_suitability.s3_ph_max IS 'Marginally suitable (S3) pH range maximum';
COMMENT ON COLUMN crop_suitability.n_ph_min IS 'Not suitable (N) pH range minimum';
COMMENT ON COLUMN crop_suitability.n_ph_max IS 'Not suitable (N) pH range maximum';

-- CROP_NUTRIENT_REQUIREMENT table: stores NPK requirements by crop and stage
CREATE TABLE crop_nutrient_requirement (
    requirement_id SERIAL PRIMARY KEY,
    crop_id INTEGER NOT NULL,
    stage_id INTEGER NOT NULL,
    n_requirement_kg_ha DECIMAL(8,2),
    p2o5_requirement_kg_ha DECIMAL(8,2),
    k2o_requirement_kg_ha DECIMAL(8,2),
    nutrient_priority VARCHAR(50),
    application_notes TEXT,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (crop_id) REFERENCES crop(crop_id) ON DELETE CASCADE,
    FOREIGN KEY (stage_id) REFERENCES growth_stage(stage_id) ON DELETE CASCADE,
    UNIQUE(crop_id, stage_id),
    CHECK (n_requirement_kg_ha >= 0),
    CHECK (p2o5_requirement_kg_ha >= 0),
    CHECK (k2o_requirement_kg_ha >= 0)
);

COMMENT ON TABLE crop_nutrient_requirement IS 'NPK requirements by crop and growth stage in kg/ha';
COMMENT ON COLUMN crop_nutrient_requirement.n_requirement_kg_ha IS 'Nitrogen requirement in kg per hectare';
COMMENT ON COLUMN crop_nutrient_requirement.p2o5_requirement_kg_ha IS 'Phosphorus (P2O5) requirement in kg per hectare';
COMMENT ON COLUMN crop_nutrient_requirement.k2o_requirement_kg_ha IS 'Potassium (K2O) requirement in kg per hectare';
COMMENT ON COLUMN crop_nutrient_requirement.nutrient_priority IS 'Priority nutrient for this stage (N, P, K, or Balanced)';

-- GROWTH_STAGE_RULE table: stores application timing rules for growth stages
CREATE TABLE growth_stage_rule (
    rule_id SERIAL PRIMARY KEY,
    stage_id INTEGER NOT NULL,
    timing_note TEXT,
    application_note TEXT,
    nutrient_emphasis VARCHAR(50),
    application_interval_days INTEGER,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stage_id) REFERENCES growth_stage(stage_id) ON DELETE CASCADE,
    CHECK (application_interval_days > 0)
);

COMMENT ON TABLE growth_stage_rule IS 'Application timing and nutrient emphasis rules for each growth stage';
COMMENT ON COLUMN growth_stage_rule.timing_note IS 'When to apply fertilizer during this stage';
COMMENT ON COLUMN growth_stage_rule.application_note IS 'How to apply fertilizer (method, placement, etc.)';
COMMENT ON COLUMN growth_stage_rule.nutrient_emphasis IS 'Which nutrient to emphasize in this stage';
COMMENT ON COLUMN growth_stage_rule.application_interval_days IS 'Recommended days between applications';

-- ============================================================================
-- FERTILIZER PRODUCT TABLES
-- ============================================================================

-- FERTILIZER_PRODUCT table: stores DA/FPA registered fertilizer products
CREATE TABLE fertilizer_product (
    product_id SERIAL PRIMARY KEY,
    company_name VARCHAR(200) NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    product_type VARCHAR(50),
    n_content_percent DECIMAL(5,2),
    p2o5_content_percent DECIMAL(5,2),
    k2o_content_percent DECIMAL(5,2),
    npk_analysis VARCHAR(50),
    registration_number VARCHAR(100) UNIQUE,
    registration_date DATE,
    expiry_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (n_content_percent >= 0 AND n_content_percent <= 100),
    CHECK (p2o5_content_percent >= 0 AND p2o5_content_percent <= 100),
    CHECK (k2o_content_percent >= 0 AND k2o_content_percent <= 100)
);

COMMENT ON TABLE fertilizer_product IS 'DA/FPA registered fertilizer products with NPK composition';
COMMENT ON COLUMN fertilizer_product.product_type IS 'Type of fertilizer (Organic, Inorganic, Bio-fertilizer, etc.)';
COMMENT ON COLUMN fertilizer_product.n_content_percent IS 'Nitrogen content percentage';
COMMENT ON COLUMN fertilizer_product.p2o5_content_percent IS 'Phosphorus (P2O5) content percentage';
COMMENT ON COLUMN fertilizer_product.k2o_content_percent IS 'Potassium (K2O) content percentage';
COMMENT ON COLUMN fertilizer_product.npk_analysis IS 'NPK analysis string (e.g., 14-14-14, 16-16-16)';
COMMENT ON COLUMN fertilizer_product.registration_number IS 'DA/FPA registration number';
COMMENT ON COLUMN fertilizer_product.is_active IS 'Whether product registration is currently active';

-- PRODUCT_CROP junction table: many-to-many relationship between products and crops
CREATE TABLE product_crop (
    product_crop_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    crop_id INTEGER NOT NULL,
    is_recommended BOOLEAN DEFAULT TRUE,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES fertilizer_product(product_id) ON DELETE CASCADE,
    FOREIGN KEY (crop_id) REFERENCES crop(crop_id) ON DELETE CASCADE,
    UNIQUE(product_id, crop_id)
);

COMMENT ON TABLE product_crop IS 'Junction table linking fertilizer products to target crops';
COMMENT ON COLUMN product_crop.is_recommended IS 'Whether this product is recommended for this crop';

-- ============================================================================
-- RECOMMENDATION AND LOGGING TABLES
-- ============================================================================

-- RECOMMENDATION_LOG table: stores each recommendation generated by the system
CREATE TABLE recommendation_log (
    recommendation_id SERIAL PRIMARY KEY,
    crop_id INTEGER NOT NULL,
    stage_id INTEGER,
    product_id INTEGER,
    profile_id INTEGER,
    input_ph DECIMAL(3,1),
    ph_source VARCHAR(50),
    pathway_type VARCHAR(50),
    recommendation_output TEXT,
    date_generated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (crop_id) REFERENCES crop(crop_id) ON DELETE CASCADE,
    FOREIGN KEY (stage_id) REFERENCES growth_stage(stage_id) ON DELETE SET NULL,
    FOREIGN KEY (product_id) REFERENCES fertilizer_product(product_id) ON DELETE SET NULL,
    FOREIGN KEY (profile_id) REFERENCES location_soil_profile(profile_id) ON DELETE SET NULL,
    CHECK (input_ph IS NULL OR (input_ph >= 0 AND input_ph <= 14))
);

COMMENT ON TABLE recommendation_log IS 'Log of all recommendations generated by the system';
COMMENT ON COLUMN recommendation_log.input_ph IS 'User-provided pH value (NULL if using location-based estimate)';
COMMENT ON COLUMN recommendation_log.ph_source IS 'Source of pH data (soil_test, location_derived)';
COMMENT ON COLUMN recommendation_log.pathway_type IS 'Recommendation pathway (suitable_soil, unsuitable_soil)';
COMMENT ON COLUMN recommendation_log.recommendation_output IS 'Complete recommendation text generated';

-- EXPLANATION_RULE table: stores explanation templates for recommendations
CREATE TABLE explanation_rule (
    explanation_id SERIAL PRIMARY KEY,
    rule_type VARCHAR(100),
    triggered_condition VARCHAR(255),
    reason_template TEXT,
    recommendation_template TEXT,
    limitation_template TEXT,
    pathway_type VARCHAR(50),
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE explanation_rule IS 'Templates for generating plain-language explanations';
COMMENT ON COLUMN explanation_rule.rule_type IS 'Type of rule (suitability, nutrient_match, amendment, etc.)';
COMMENT ON COLUMN explanation_rule.triggered_condition IS 'Condition that triggers this explanation';
COMMENT ON COLUMN explanation_rule.reason_template IS 'Template for explaining the reasoning';
COMMENT ON COLUMN explanation_rule.recommendation_template IS 'Template for the recommendation text';
COMMENT ON COLUMN explanation_rule.limitation_template IS 'Template for limitation notes';

-- VALIDATION_LOG table: stores expert validation records
CREATE TABLE validation_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER,
    reviewed_item TEXT,
    expert_comment TEXT,
    decision VARCHAR(50),
    validator_name VARCHAR(200),
    review_date DATE,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE validation_log IS 'Expert validation records for knowledge base quality control';
COMMENT ON COLUMN validation_log.table_name IS 'Name of table being validated';
COMMENT ON COLUMN validation_log.record_id IS 'ID of the specific record being validated';
COMMENT ON COLUMN validation_log.reviewed_item IS 'Description of what was reviewed';
COMMENT ON COLUMN validation_log.expert_comment IS 'Expert feedback and comments';
COMMENT ON COLUMN validation_log.decision IS 'Validation decision (Accepted, Rejected, Needs_Revision)';

-- ============================================================================
-- INDEXES for improved query performance
-- ============================================================================

-- Crop indexes
CREATE INDEX idx_crop_name ON crop(crop_name);
CREATE INDEX idx_crop_active ON crop(is_active);

-- Growth stage indexes
CREATE INDEX idx_growth_stage_crop ON growth_stage(crop_id);
CREATE INDEX idx_growth_stage_order ON growth_stage(crop_id, stage_order);

-- Location soil profile indexes
CREATE INDEX idx_location_barangay ON location_soil_profile(barangay_location);

-- Crop suitability indexes
CREATE INDEX idx_suitability_crop ON crop_suitability(crop_id);

-- Nutrient requirement indexes
CREATE INDEX idx_nutrient_crop_stage ON crop_nutrient_requirement(crop_id, stage_id);

-- Fertilizer product indexes
CREATE INDEX idx_product_active ON fertilizer_product(is_active);
CREATE INDEX idx_product_registration ON fertilizer_product(registration_number);
CREATE INDEX idx_product_expiry ON fertilizer_product(expiry_date);
CREATE INDEX idx_product_company ON fertilizer_product(company_name);

-- Product crop indexes
CREATE INDEX idx_product_crop_product ON product_crop(product_id);
CREATE INDEX idx_product_crop_crop ON product_crop(crop_id);

-- Recommendation log indexes
CREATE INDEX idx_recommendation_crop ON recommendation_log(crop_id);
CREATE INDEX idx_recommendation_date ON recommendation_log(date_generated);
CREATE INDEX idx_recommendation_pathway ON recommendation_log(pathway_type);

-- Validation log indexes
CREATE INDEX idx_validation_table ON validation_log(table_name);
CREATE INDEX idx_validation_date ON validation_log(review_date);

-- ============================================================================
-- TRIGGERS for automatic timestamp updates
-- ============================================================================

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.date_updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_timestamp() IS 'Automatically updates date_updated column on record modification';

-- Triggers for tables with date_updated column
CREATE TRIGGER update_crop_timestamp
    BEFORE UPDATE ON crop
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_location_soil_profile_timestamp
    BEFORE UPDATE ON location_soil_profile
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_fertilizer_product_timestamp
    BEFORE UPDATE ON fertilizer_product
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- SAMPLE DATA for initial setup
-- ============================================================================

-- Insert initial crops
INSERT INTO crop (crop_name, scientific_name, crop_category, description) VALUES
('Cacao', 'Theobroma cacao', 'Perennial', 'High-value perennial crop for chocolate production'),
('Durian', 'Durio zibethinus', 'Perennial', 'High-value tropical fruit known as king of fruits');

-- Insert growth stages for Cacao
INSERT INTO growth_stage (crop_id, stage_name, stage_order, duration_days_min, duration_days_max, stage_description) VALUES
(1, 'Nursery', 1, 0, 180, 'Seedling establishment phase'),
(1, 'Vegetative', 2, 180, 730, 'Active vegetative growth'),
(1, 'Flowering', 3, 730, 1095, 'Flower production phase'),
(1, 'Fruiting', 4, 1095, 1460, 'Pod development and maturation'),
(1, 'Maintenance', 5, 1460, NULL, 'Mature tree maintenance');

-- Insert growth stages for Durian
INSERT INTO growth_stage (crop_id, stage_name, stage_order, duration_days_min, duration_days_max, stage_description) VALUES
(2, 'Nursery', 1, 0, 365, 'Seedling establishment phase'),
(2, 'Vegetative', 2, 365, 1460, 'Active vegetative growth'),
(2, 'Pre-flowering', 3, 1460, 1825, 'Pre-flowering phase'),
(2, 'Flowering', 4, 1825, 2190, 'Flower production phase'),
(2, 'Fruiting', 5, 2190, 2555, 'Fruit development and maturation'),
(2, 'Maintenance', 6, 2555, NULL, 'Mature tree maintenance');

-- ============================================================================
-- UTILITY VIEWS for common queries
-- ============================================================================

-- View: Active crops with their growth stages
CREATE VIEW v_crop_stages AS
SELECT 
    c.crop_id,
    c.crop_name,
    c.scientific_name,
    gs.stage_id,
    gs.stage_name,
    gs.stage_order,
    gs.duration_days_min,
    gs.duration_days_max
FROM crop c
INNER JOIN growth_stage gs ON c.crop_id = gs.crop_id
WHERE c.is_active = TRUE
ORDER BY c.crop_name, gs.stage_order;

COMMENT ON VIEW v_crop_stages IS 'Active crops with their growth stages in order';

-- View: Active fertilizer products with NPK content
CREATE VIEW v_active_fertilizers AS
SELECT 
    product_id,
    company_name,
    product_name,
    product_type,
    n_content_percent,
    p2o5_content_percent,
    k2o_content_percent,
    npk_analysis,
    registration_number,
    expiry_date
FROM fertilizer_product
WHERE is_active = TRUE
    AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
ORDER BY company_name, product_name;

COMMENT ON VIEW v_active_fertilizers IS 'Currently active and non-expired fertilizer products';

-- View: Crop nutrient requirements summary
CREATE VIEW v_crop_nutrient_summary AS
SELECT 
    c.crop_name,
    gs.stage_name,
    gs.stage_order,
    cnr.n_requirement_kg_ha,
    cnr.p2o5_requirement_kg_ha,
    cnr.k2o_requirement_kg_ha,
    cnr.nutrient_priority,
    cnr.application_notes
FROM crop c
INNER JOIN growth_stage gs ON c.crop_id = gs.crop_id
INNER JOIN crop_nutrient_requirement cnr ON gs.stage_id = cnr.stage_id
WHERE c.is_active = TRUE
ORDER BY c.crop_name, gs.stage_order;

COMMENT ON VIEW v_crop_nutrient_summary IS 'Nutrient requirements by crop and growth stage';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Query to verify schema setup
-- SELECT table_name, table_type 
-- FROM information_schema.tables 
-- WHERE table_schema = 'public' 
-- ORDER BY table_name;

-- Query to verify foreign key relationships
-- SELECT 
--     tc.table_name, 
--     kcu.column_name, 
--     ccu.table_name AS foreign_table_name,
--     ccu.column_name AS foreign_column_name 
-- FROM information_schema.table_constraints AS tc 
-- JOIN information_schema.key_column_usage AS kcu
--     ON tc.constraint_name = kcu.constraint_name
--     AND tc.table_schema = kcu.table_schema
-- JOIN information_schema.constraint_column_usage AS ccu
--     ON ccu.constraint_name = tc.constraint_name
--     AND ccu.table_schema = tc.table_schema
-- WHERE tc.constraint_type = 'FOREIGN KEY'
-- ORDER BY tc.table_name, kcu.column_name;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
