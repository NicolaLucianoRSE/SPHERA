!-------------------------------------------------------------------------------
! SPHERA v.9.0.0 (Smoothed Particle Hydrodynamics research software; mesh-less
! Computational Fluid Dynamics code).
! Copyright 2005-2020 (RSE SpA -formerly ERSE SpA, formerly CESI RICERCA,
! formerly CESI-Ricerca di Sistema)
!
! SPHERA authors and email contact are provided on SPHERA documentation.
!
! This file is part of SPHERA v.9.0.0
! SPHERA v.9.0.0 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
! SPHERA is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
! You should have received a copy of the GNU General Public License
! along with SPHERA. If not, see <http://www.gnu.org/licenses/>.
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! Program unit: PressureSmoothing_3D
! Description: Partial smoothing for pressure (Di Monaco et al., 2011), also
!              with DB-SPH boundary treatment scheme. This subroutine is not 
!              just the formal 3D extension of PressureSmoothing_2D: 
!              differences are appreciable.
!-------------------------------------------------------------------------------
subroutine PressureSmoothing_3D
!------------------------
! Modules
!------------------------
use I_O_file_module
use Static_allocation_module
use Hybrid_allocation_module
use Dynamic_allocation_module
!------------------------
! Declarations
!------------------------
implicit none
double precision, parameter :: MinTotUnit = 0.95d0
! You may consider "complete" or = "incomplete"
character(10), parameter :: SmoothingNormalisation = "complete  "          
integer(4) :: npi,npj,nsp,icbf,Ncbf,ibdt,ibdp,ii,j,npartint
double precision :: p0i,pi,sompW,pesoj,DiffP,TetaP1,Appunity,IntWdV
double precision,dimension(:),allocatable :: sompW_vec,AppUnity_vec    
!------------------------
! Explicit interfaces
!------------------------
!------------------------
! Allocations
!------------------------
!------------------------
! Initializations
!------------------------
if (n_bodies>0) then  
   allocate(sompW_vec(nag))
   allocate(AppUnity_vec(nag))
   sompW_vec = zero
   AppUnity_vec = zero
endif
!------------------------
! Statements
!------------------------
! Body particle contributions to pressure smoothing
if (n_bodies>0) then
   call start_and_stop(2,19)
   call body_to_smoothing_pres(sompW_vec,AppUnity_vec)
   call start_and_stop(3,19)
endif
!$omp parallel do default(none)                                                &
!$omp private(npi,ii,Nsp,DiffP,p0i,pi,sompW,Appunity)                          &
!$omp private(j,npartint,npj,pesoj,Ncbf,ibdt,icbf,ibdp,intWdV)                 &
!$omp shared(pg,Domain,nPartIntorno,PartIntorno,NMAXPARTJ,PartKernel)          &
!$omp shared(BoundaryDataPointer,BoundaryDataTab,indarrayFlu,Array_Flu)        &
!$omp shared(sompW_vec,AppUnity_vec,n_bodies)
do ii=1,indarrayFlu
   npi = Array_Flu(ii)
! Excluding particles close to the face with conditions "flow", "velo" and "sour"
   if (pg(npi)%koddens==0) then 
      DiffP = zero
      Nsp = nPartIntorno(npi)
      if (Nsp>0) then
         p0i = Domain%prif
         pi = pg(npi)%pres
         sompW = zero
         Appunity = zero
         do j=1,Nsp
            npartint = (npi - 1) * NMAXPARTJ + j
            npj = PartIntorno(npartint)
            pesoj = pg(npj)%mass * PartKernel(4,npartint) / pg(npj)%dens
            Appunity = Appunity + pesoj
            sompW = sompW + (pg(npj)%pres - pi) * pesoj
         enddo
         if (n_bodies>0) then
            sompW = sompW + sompW_vec(npi)
            AppUnity = AppUnity + AppUnity_vec(npi)
         endif
         if (Domain%tipo=="bsph") then
! DB-SPH contributions to pressure smoothing
            pg(npi)%vpres = sompW / AppUnity
            else
! SA-SPH contributions to pressure smoothing
               Ncbf = BoundaryDataPointer(1,npi)
               ibdt = BoundaryDataPointer(3,npi)
               if (Ncbf>0) then
                  do icbf=1,Ncbf
                     ibdp = ibdt + icbf - 1
                     if (BoundaryDataTab(ibdp)%LocXYZ(3)>zero) then
                        IntWdV = BoundaryDataTab(ibdp)%BoundaryIntegral(2)
                        AppUnity = AppUnity + IntWdV
                     endif
                  enddo
               endif
               if (SmoothingNormalisation=="complete  ") then
                  if (AppUnity<MinTotUnit) then
! in case of non-null reference pressure
                     DiffP = sompW + (p0i - pi) * (one - AppUnity)  
                     else
                     DiffP = sompW / AppUnity
                  endif
                  elseif (SmoothingNormalisation=="incomplete") then
                     DiffP = sompW / AppUnity
               endif
         endif
      endif
      if (Domain%tipo=="semi") pg(npi)%vpres = DiffP
   endif
enddo
!$omp end parallel do
!$omp parallel do default(none)                                                &
!$omp shared(pg,Med,Domain,dt,indarrayFlu,Array_Flu)                           &
!$omp private(npi,ii,TetaP1)
do ii=1,indarrayFlu
   npi = Array_Flu(ii)
! Excluding particles close to the face with conditions "flow", "velo" and 
! "sour"
   if (pg(npi)%koddens==0) then 
! Computing TetaP depending on the time step
      TetaP1 = Domain%TetaP * Med(pg(npi)%imed)%Celerita * dt / Domain%h
      pg(npi)%pres = pg(npi)%pres + TetaP1 * pg(npi)%vpres
      pg(npi)%dens = Med(pg(npi)%imed)%den0 * (one + (pg(npi)%pres -           &
                     Domain%Prif) / Med(pg(npi)%imed)%eps)
   endif
enddo
!$omp end parallel do
!------------------------
! Deallocations
!------------------------
if (n_bodies>0) then
   deallocate(sompW_vec)
   deallocate(AppUnity_vec)
endif
return
end subroutine PressureSmoothing_3D
