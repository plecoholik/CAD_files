// ==========================================================
// 0. RENDER CONTROL & HARDWARE SELECTION
// ==========================================================
part_to_render = "both"; 
hardware_size  = "M3";   

// ==========================================================
// 1. HARDWARE DATA TABLE
// ==========================================================
hw_data = (hardware_size == "M2")   ? [2.4, 3.2, 5.0] :
          (hardware_size == "M2.5") ? [2.9, 3.8, 6.0] :
          /* Default M3 */            [3.4, 4.2, 7.0];

clearance_d    = hw_data[0]; 
insert_hole_d  = hw_data[1]; 
pillar_min_d   = hw_data[2]; 

// ==========================================================
// 2. GLOBAL CONFIGURATION
// ==========================================================
nozzle_d       = 0.4;    
line_w         = nozzle_d * 1.125;
perimeters     = 3;
wall_t         = line_w * perimeters; 

pcb_w          = 140;    
pcb_h          = 35;     
pcb_t          = 1.6;    
fit_gap        = 0.15;   
fit_clearance  = 0.1;    

// ==========================================================
// 3. COMPONENT PARAMETERS
// ==========================================================
f_thick        = 1.2;    
flange_min     = 3.0;    
relief         = 12.0;   
snap_ext       = 0.8;    
barb_flat_h    = 0.5;
snap_ramp_v    = snap_ext;
min_arm_len    = snap_ext * 5;

cover_depth    = 15.0;   
cover_thick    = 1.2;    
wire_gate_w    = 12.0;   
wire_gate_h    = 8.0;    
show_gates     = [1, 1, 0, 0]; // [North, South, East, West]
insert_depth   = 5.0;    

// ==========================================================
// 4. SHARED CALCULATIONS
// ==========================================================
io_w           = 160; 
io_h           = 45; 
case_t         = 0.5;

shift_w        = (io_w - pcb_w) / 2;
shift_h        = (io_h - pcb_h) / 2;
h_center_dist  = 3.0 + (clearance_d / 2);

// ==========================================================
// 5. MODULES: FRAME
// ==========================================================

module case_snap_profile() {
    lock_z = f_thick + case_t + fit_clearance;
    polygon(points=[[0,0],[wall_t,0],[wall_t,max(min_arm_len, lock_z + snap_ramp_v*2 + barb_flat_h)],[0,max(min_arm_len, lock_z + snap_ramp_v*2 + barb_flat_h)],[-snap_ext, lock_z+snap_ramp_v+barb_flat_h],[-snap_ext, lock_z+snap_ramp_v],[0,lock_z],[0,0]]);
}

module pcb_snap_profile(pcb_pos) {
    lock_z = f_thick + pcb_t + fit_clearance;
    translate([pcb_pos, 0, 0])
    polygon(points=[[0,0],[wall_t,0],[wall_t,lock_z],[wall_t+snap_ext,lock_z+snap_ramp_v],[wall_t+snap_ext,lock_z+snap_ramp_v+barb_flat_h],[wall_t,max(min_arm_len, lock_z + snap_ramp_v*2 + barb_flat_h)],[0,max(min_arm_len, lock_z + snap_ramp_v*2 + barb_flat_h)],[0,0]]);
}

module universal_wall(length, pcb_pos) {
    active_len = length - (relief * 2);
    num_segs   = max(1, floor(active_len / 10)); 
    rotate([90, 0, 90]) union() {
        linear_extrude(height = active_len) square([max(wall_t, pcb_pos + wall_t), f_thick]);
        for (i = [0 : num_segs - 1]) {
            translate([0, 0, i * (active_len/num_segs)])
            linear_extrude(height = (active_len/num_segs) - 0.5)
            if (i % 2 == 0) case_snap_profile(); else pcb_snap_profile(pcb_pos);
        }
    }
}

module render_frame() {
    boss_size = (h_center_dist * 2) + (clearance_d * 1.2);
    difference() {
        union() {
            difference() {
                translate([-flange_min, -flange_min, 0]) cube([io_w + flange_min*2, io_h + flange_min*2, f_thick]);
                translate([shift_w + 2, shift_h + 2, -1]) cube([pcb_w - 4, pcb_h - 4, f_thick + 2]);
            }
            for(x_d=[0, 1], y_d=[0, 1]) {
                x_p = (x_d == 0) ? shift_w : io_w - shift_w;
                y_p = (y_d == 0) ? shift_h : io_h - shift_h;
                translate([x_p, y_p, 0]) linear_extrude(f_thick) 
                    rotate([0, 0, x_d*90 + y_d*(x_d==1 ? 90 : 270)]) 
                    polygon(points=[[0,0], [boss_size,0], [0,boss_size]]);
            }
            translate([relief, 0, 0]) universal_wall(io_w, shift_h - wall_t - fit_gap);
            translate([io_w - relief, io_h, 0]) rotate([0, 0, 180]) universal_wall(io_w, shift_h - wall_t - fit_gap);
            translate([0, io_h - relief, 0]) rotate([0, 0, -90]) universal_wall(io_h, shift_w - wall_t - fit_gap);
            translate([io_w, relief, 0]) rotate([0, 0, 90]) universal_wall(io_h, shift_w - wall_t - fit_gap);
        }
        for(x_p = [shift_w + h_center_dist, io_w - shift_w - h_center_dist], 
            y_p = [shift_h + h_center_dist, io_h - shift_h - h_center_dist])
            translate([x_p, y_p, -1]) cylinder(d=clearance_d, h=f_thick + 2, $fn=24);
    }
}

// ==========================================================
// 6. MODULES: COVER (Clean Gates)
// ==========================================================

module render_cover() {
    c_inner_w = pcb_w + (fit_gap * 2);
    c_inner_h = pcb_h + (fit_gap * 2);
    c_outer_w = c_inner_w + (wall_t * 2);
    c_outer_h = c_inner_h + (wall_t * 2);
    extension_h = case_t + f_thick; 
    actual_pillar_d = min(pillar_min_d, (shift_w + h_center_dist) * 1.8);

    difference() {
        union() {
            // Main Body Tub
            difference() {
                translate([shift_w - wall_t - fit_gap, shift_h - wall_t - fit_gap, 0])
                    cube([c_outer_w, c_outer_h, cover_depth + cover_thick]);
                translate([shift_w - fit_gap, shift_h - fit_gap, cover_thick]) 
                    cube([c_inner_w, c_inner_h, cover_depth + 1]);
            }
            // Two-Stage Pillars
            for(x_d=[0, 1], y_d=[0, 1]) {
                target_x = (x_d == 0) ? shift_w + h_center_dist : io_w - shift_w - h_center_dist;
                target_y = (y_d == 0) ? shift_h + h_center_dist : io_h - shift_h - h_center_dist;
                corner_x = (x_d == 0) ? shift_w - fit_gap : shift_w + pcb_w + fit_gap;
                corner_y = (y_d == 0) ? shift_h - fit_gap : shift_h + pcb_h + fit_gap;
                hull() {
                    translate([target_x, target_y, cover_thick]) cylinder(d = actual_pillar_d, h = cover_depth, $fn=24);
                    translate([corner_x, corner_y, cover_thick]) cylinder(d = wall_t*2, h = cover_depth, $fn=16);
                }
                translate([target_x, target_y, cover_thick + cover_depth]) cylinder(d = actual_pillar_d, h = extension_h, $fn=24);
            }
        }
        
        // 1. HEAT-SET INSERT HOLES
        for(x_p = [shift_w + h_center_dist, io_w - shift_w - h_center_dist], 
            y_p = [shift_h + h_center_dist, io_h - shift_h - h_center_dist]) {
            translate([x_p, y_p, cover_thick + cover_depth + extension_h - insert_depth]) 
                cylinder(d = insert_hole_d, h = insert_depth + 1, $fn=24);
        }

        // 2. CLEAN WIRE GATES (Cutting through floor and wall)
        // Positioned at the top (open side) of the cover, extending down
        gate_full_h = wire_gate_h + cover_thick; // Ensure it breaks the floor
        gate_y_off = shift_h - fit_gap - wall_t - 1;
        gate_x_off = shift_w - fit_gap - wall_t - 1;

        // North Gate
        if (show_gates[0]) translate([io_w/2 - wire_gate_w/2, shift_h + pcb_h + fit_gap - 1, cover_depth + cover_thick - wire_gate_h]) 
            cube([wire_gate_w, wall_t + 2, wire_gate_h + 1]);
        
        // South Gate
        if (show_gates[1]) translate([io_w/2 - wire_gate_w/2, shift_h - fit_gap - wall_t - 1, cover_depth + cover_thick - wire_gate_h]) 
            cube([wire_gate_w, wall_t + 2, wire_gate_h + 1]);

        // East Gate
        if (show_gates[2]) translate([shift_w + pcb_w + fit_gap - 1, io_h/2 - wire_gate_w/2, cover_depth + cover_thick - wire_gate_h]) 
            cube([wall_t + 2, wire_gate_w, wire_gate_h + 1]);

        // West Gate
        if (show_gates[3]) translate([shift_w - fit_gap - wall_t - 1, io_h/2 - wire_gate_w/2, cover_depth + cover_thick - wire_gate_h]) 
            cube([wall_t + 2, wire_gate_w, wire_gate_h + 1]);
    }
}

// ==========================================================
// 7. EXECUTION
// ==========================================================
if (part_to_render == "frame" || part_to_render == "both") render_frame();
if (part_to_render == "cover" || part_to_render == "both") {
    z_off = (part_to_render == "both") ? 40 : 0;
    translate([0, 0, z_off]) render_cover();
}