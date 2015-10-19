!----------------------------------------------------------------------------------------------------------------------------------
! SPHERA (Smoothed Particle Hydrodynamics research software; mesh-less Computational Fluid Dynamics code).
! Copyright 2005-2015 (RSE SpA -formerly ERSE SpA, formerly CESI RICERCA, formerly CESI-) 
!      
!     
!   
!      
!  

! This file is part of SPHERA.
!  
!  
!  
!  
! SPHERA is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
!  
!  
!  
!----------------------------------------------------------------------------------------------------------------------------------

!----------------------------------------------------------------------------------------------------------------------------------
! Program unit: ReadDBSPH                    
! Description: Reading input data for the DB-SPH boundary treatment scheme (Amicarelli et al., 2013, IJNME).                   
!----------------------------------------------------------------------------------------------------------------------------------
subroutine ReadDBSPH(ainp,comment,nrighe,ier,ninp,nout)
!------------------------
! Modules
!------------------------ 
use Static_allocation_module
use Dynamic_allocation_module
use I_O_diagnostic_module
!------------------------
! Declarations
!------------------------
implicit none
integer(4),intent(inout) :: nrighe,ier,ninp,nout
character(1),intent(inout) :: comment
character(100),intent(inout) :: ainp 
logical :: MUSCL_boundary_flag,in_built_monitors
integer(4) :: ioerr,n_monitor_points,n_monitor_regions,i,alloc_stat            
integer(4) :: dealloc_stat,j,n_inlet,n_outlet
integer(4) :: ply_n_face_vert,surface_mesh_files
double precision :: dx_dxw,k_w
character(100) :: lcase
integer(4) :: n_kinematics_records(100)
integer(4),allocatable,dimension(:) :: monitor_IDs
double precision :: monitor_region(6)           
double precision :: rotation_centre(100,3)
logical,external :: ReadCheck
!------------------------
! Explicit interfaces
!------------------------
!------------------------
! Allocations
!------------------------
!------------------------
! Initializations
!------------------------
n_kinematics_records(:) = 0
!------------------------
! Statements
!------------------------
! In case of restart, input data are not read
if (restart) then
! Lower case letters are required
   do while (TRIM(lcase(ainp))/="##### end dbsph #####") 
      call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
      if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH DATA",ninp,nout)) return
   enddo
  return
endif
call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH DATA",ninp,nout)) return
do while (TRIM(lcase(ainp))/="##### end dbsph #####")
! Reading the ratio between the fluid and the semi-particle sizes (dx/dx_w)
   read(ainp,*,iostat=ioerr) dx_dxw,MUSCL_boundary_flag,k_w
   if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH GENERAL INPUT",ninp,nout))  &
      return
   call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
   read(ainp,*,iostat=ioerr) n_monitor_points,n_monitor_regions
   if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH_monitor_numbers",ninp,nout))&
      return
   if (n_monitor_points>0) then
      if (.not.allocated(monitor_IDs)) allocate(monitor_IDs(n_monitor_points),&
         STAT=alloc_stat)
      if (alloc_stat/=0) then
         write(nout,*)                                                         &
'Allocation of monitor_IDs in ReadDBSPH failed; the program terminates here'
! Stop the main program
         stop 
      endif
      call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
      read(ainp,*,iostat=ioerr) monitor_IDs(:)
      if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH_monitor_IDs",ninp,nout)) &
         return
      endif
      if (n_monitor_regions==1) then
         call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
         read(ainp,*,iostat=ioerr) monitor_region(:)
         if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH_monitor_region",ninp, &
            nout)) return
      endif
      call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
      read(ainp,*,iostat=ioerr) surface_mesh_files,in_built_monitors
      if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"SURFACE_MESH_FILES",ninp,nout))&
         return  
      do i=1,surface_mesh_files
         call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
         read(ainp,*,iostat=ioerr) n_kinematics_records(i),rotation_centre(i,:)
         if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH_KINEMATICS",ninp,nout &
            )) return  
         if (.not.(allocated(DBSPH%kinematics))) then
            allocate(DBSPH%kinematics(surface_mesh_files,                      &
               n_kinematics_records(i),7),STAT=alloc_stat)
            if (alloc_stat/=0) then
               write(nout,*)                                                   &
'Error! Allocation of DBSPH%kinematics in ReadDBSPH failed; the program terminates here.'
               call diagnostic(arg1=5,arg2=340)
! Stop the main program
               stop 
               else
                  write(nout,'(1x,a)')                                         &
"Array DBSPH%kinematics successfully allocated in subroutine ReadDBSPH."
            endif
         endif  
         do j=1,n_kinematics_records(i)
            call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
            read(ainp,*,iostat=ioerr) DBSPH%kinematics(i,j,:)  
            if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH_KINEMATICS_RECORDS"&
               ,ninp,nout)) return            
         enddo
      enddo
      call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
      read(ainp,*,iostat=ioerr) n_inlet,n_outlet,ply_n_face_vert
      if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,                                &
         "DBSPH_INLET_OUTLET_PLY_N_FACE_VERT",ninp,nout)) return 
      if (n_inlet>0) then
         if (.not.allocated(DBSPH%inlet_sections)) then
            allocate(DBSPH%inlet_sections(n_inlet,10),STAT=alloc_stat)
            if (alloc_stat/=0) then
               write(nout,*)                                                   &
'Allocation of DBSPH%inlet_sections in ReadDBSPH failed; the program terminates here'
! Stop the main program
               stop 
         endif
      endif
   endif
   do j=1,n_inlet
      call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
! Reading position, normal and velocity of an inlet surface element      
      read(ainp,*,iostat=ioerr) DBSPH%inlet_sections(j,:)  
      if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH_INLET_SECTIONS",ninp,    &
         nout)) return            
   enddo 
   if (n_outlet>0) then
! Reading position and normal of an outlet surface element       
      if (.not.allocated(DBSPH%outlet_sections)) then
         allocate(DBSPH%outlet_sections(n_outlet,8),STAT=alloc_stat)
         if (alloc_stat/=0) then
            write(nout,*)                                                      &
'Allocation of DBSPH_outlet_sections in ReadDBSPH failed; the program terminates here'
! Stop the main program
            stop 
         endif
      endif   
   endif
   do j=1,n_outlet
      call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
      read(ainp,*,iostat=ioerr) DBSPH%outlet_sections(j,:)  
      if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH_OUTLET_SECTIONS",ninp,   &
         nout)) return            
   enddo
! Writing the DB-SPH input parameters on the log file
   if ((ncord>0).and.(nout > 0)) then
      write(nout,"(1x,a,1p,e12.4)")                                            &
"dx/dx_w:........................",dx_dxw
      write(nout,"(1x,a,1p,l12)")                                              &
"MUSCL_boundary_flag:............",MUSCL_boundary_flag
      write(nout,"(1x,a,1p,e12.4)")                                            &
"k_w(semi-particle coefficient)..",k_w
      write(nout,"(1x,a,1p,i12)")                                              &
"n_monitor_points................",n_monitor_points       
      if (n_monitor_points>0) then
         do i=1,n_monitor_points
            write(nout,"(1x,a,1p,e12.4)")                                      &
"ID_monitor......................",monitor_IDs(i)        
         enddo    
      endif
      write(nout,"(1x,a,1p,i12)")                                              &
"n_monitor_regions...............",n_monitor_regions        
      if (n_monitor_regions==1) then
         write(nout,"(1x,a,1p,g12.5)")                                         &
"monitor_region_x_min: ..........",monitor_region(1)
         write(nout,"(1x,a,1p,g12.5)")                                         &
"monitor_region_x_max: ..........",monitor_region(2)
         write(nout,"(1x,a,1p,g12.5)")                                         &
"monitor_region_y_min: ..........",monitor_region(3)
         write(nout,"(1x,a,1p,g12.5)")                                         &
"monitor_region_y_max: ..........",monitor_region(4)
         write(nout,"(1x,a,1p,g12.5)")                                         &
"monitor_region_z_min: ..........",monitor_region(5)
         write(nout,"(1x,a,1p,g12.5)")                                         &
"monitor_region_z_max: ..........",monitor_region(6)
      endif
      write(nout,"(1x,a,1p,i12)")                                              &
"surface_mesh_files..............",surface_mesh_files 
      write(nout,"(1x,a,1p,l12)")                                              &
"in-built_monitor_flag:..........",in_built_monitors
      do j=1,surface_mesh_files 
         write(nout,"(1x,a,1p,i12)")                                           &
"n_kinematics_records............",n_kinematics_records(j) 
         write(nout,"(1x,a,1p,3(g12.4))")                                      &
"rotation_centre:................",rotation_centre(j,:) 
         do i=1,n_kinematics_records(j)
            write(nout,"(1x,a,1p,7(g12.4))")                                   &
"time(s),u(m/s),v(m/s),w(m/s),omega_x(rad/s),omega_y(rad/s),omega_z(rad/s):..."&
               ,DBSPH%kinematics(j,i,:)        
         enddo
      enddo 
      write(nout,"(1x,a,i12)")                                                 &
"n_inlet:........................",n_inlet
      do i=1,n_inlet
         write(nout,"(1x,a,1p,9(g12.4))")                                      &
"x(m),y(m),z(m),n_x,n_y,n_z,u(m/s),v(m/s),w(m/s),length(m): ",                 &
            DBSPH%inlet_sections(i,:)        
      enddo 
      write(nout,"(1x,a,i12)")                                                 &
"n_outlet:.......................",n_outlet
      do i=1,n_outlet
         write(nout,"(1x,a,1p,6(g12.4))")                                      &
"x(m),y(m),z(m),n_x,n_y,n_z,length(m),pres(Pa)............: ",                 &
            DBSPH%outlet_sections(i,:)        
      enddo   
      write(nout,"(1x,a,i12)")                                                 &
"ply_n_face_vert:................",ply_n_face_vert    
      write(nout,"(1x,a)")  " "
! Assignment of the DB-SPH parameters 
      DBSPH%dx_dxw = dx_dxw
      DBSPH%MUSCL_boundary_flag = MUSCL_boundary_flag
      DBSPH%k_w = k_w
      DBSPH%n_monitor_points = n_monitor_points 
      DBSPH%n_monitor_regions = n_monitor_regions
      DBSPH%monitor_region(:) = monitor_region(:)  
      if (n_monitor_points>0) then
         if (.not.(allocated(DBSPH%monitor_IDs))) then
            allocate(DBSPH%monitor_IDs(n_monitor_points),STAT=alloc_stat)
            if (alloc_stat/=0) then
               write(nout,*)                                                   &
'Allocation of DBSPH%n_monitor_points in ReadDBSPH failed; the program terminates here.'
! Stop the main program
               stop 
            endif   
         endif       
         DBSPH%monitor_IDs(:) = monitor_IDs(:)
      endif
      DBSPH%surface_mesh_files = surface_mesh_files
      DBSPH%in_built_monitors = in_built_monitors
      if (.not.(allocated(DBSPH%n_kinematics_records))) then
         allocate(DBSPH%n_kinematics_records(surface_mesh_files),              &
            STAT=alloc_stat)
         if (alloc_stat/=0) then
            write(nout,*)                                                      &
'Error! Allocation of DBSPH%n_kinematics_records in ReadDBSPH failed; the program terminates here.'
            call diagnostic(arg1=5,arg2=340)
! Stop the main program
            stop 
            else
               write(nout,'(1x,a)')                                            &
"Array DBSPH%n_kinematics_records successfully allocated in subrouitne ReadDBSPH."
         endif
      endif
      if (.not.(allocated(DBSPH%rotation_centre))) then
         allocate(DBSPH%rotation_centre(surface_mesh_files,3),STAT=alloc_stat)
         if (alloc_stat/=0) then
            write(nout,*)                                                      &
'Error! Allocation of DBSPH%rotation_centre in ReadDBSPH failed; the program terminates here.'
            call diagnostic(arg1=5,arg2=340)
! Stop the main program
            stop 
            else
               write(nout,'(1x,a)')                                            &
"Array DBSPH%rotation_centre successfully allocated in subrouitne ReadDBSPH."
         endif
      endif
      do i=1,surface_mesh_files
         DBSPH%n_kinematics_records(i) = n_kinematics_records(i)
         DBSPH%rotation_centre(i,:) = rotation_centre(i,:)
      enddo 
      DBSPH%n_inlet = n_inlet   
      DBSPH%n_outlet = n_outlet
      DBSPH%ply_n_face_vert = ply_n_face_vert
   endif
   if (allocated(monitor_IDs)) then
      deallocate(monitor_IDs,STAT=dealloc_stat)
      if (dealloc_stat/=0) then
         write(nout,*)                                                         &
'Deallocation of monitor_IDs in ReadDBSPH failed; the program terminates here.'
! Stop the main program
         stop 
      endif   
   endif   
   call ReadRiga(ainp,comment,nrighe,ioerr,ninp)
   if (.NOT.ReadCheck(ioerr,ier,nrighe,ainp,"DBSPH DATA",ninp,nout)) return
enddo
!------------------------
! Deallocations
!------------------------
return
end subroutine ReadDBSPH

