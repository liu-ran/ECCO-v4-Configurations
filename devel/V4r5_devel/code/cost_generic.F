C $Header: /u/gcmpack/MITgcm/pkg/ecco/cost_generic.F,v 1.39 2016/03/22 22:29:25 gforget Exp $
C $Name:  $

#include "ECCO_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: cost_generic
C     !INTERFACE:
      subroutine cost_generic(
     &     nnzbar, localbarfile, dummy,
     &     nnzobs, localobsfile, localerrfile,
     &     mult_local, nrecloc, nrecobs,
     &     localstartdate, localperiod,
     &     ylocmask, spminloc, spmaxloc, spzeroloc,
     &     preproc, preproc_c, preproc_i, preproc_r,
     &     posproc, posproc_c, posproc_i, posproc_r,
     &     outlev, outname,
     &     objf_local, num_local,
     &     myIter, myTime, myThid )

C     !DESCRIPTION: \bv
C     Generic routine for evaluating time-dependent
c       cost function contribution
C     \ev

C     !USES:
      implicit none

c     == global variables ==

#include "EEPARAMS.h"
#include "SIZE.h"
#include "PARAMS.h"
#include "GRID.h"
#ifdef ALLOW_CAL
# include "cal.h"
#endif
#ifdef ALLOW_ECCO
# include "ecco.h"
#endif
#ifdef ALLOW_SEAICE
# include "SEAICE_COST.h"
#endif

c     == routine arguments ==

      integer myIter
      integer myThid
      integer nnzbar, nnzobs
      integer nrecloc, nrecobs
      integer localstartdate(4)
      integer outlev
      integer preproc_i(NGENPPROC)
      integer posproc_i(NGENPPROC)

      _RL objf_local(nSx,nSy)
      _RL num_local(nSx,nSy)
      _RL dummy
      _RL mult_local
      _RL myTime
      _RL localperiod
      _RL spminloc
      _RL spmaxloc
      _RL spzeroloc
      _RL preproc_r(NGENPPROC)
      _RL posproc_r(NGENPPROC)

      character*(1) ylocmask
      character*(MAX_LEN_FNAM) localbarfile
      character*(MAX_LEN_FNAM) localobsfile
      character*(MAX_LEN_FNAM) localerrfile
      character*(MAX_LEN_FNAM) preproc(NGENPPROC)
      character*(MAX_LEN_FNAM) preproc_c(NGENPPROC)
      character*(MAX_LEN_FNAM) posproc(NGENPPROC)
      character*(MAX_LEN_FNAM) posproc_c(NGENPPROC)
      character*(MAX_LEN_FNAM) outname

#ifdef ALLOW_ECCO

c     == local variables ==

      integer bi,bj,k2
      integer itlo,ithi
      integer jtlo,jthi
      logical domean, doanom, dotrend

      _RL localdifmean1  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localdifmean2  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)

CEOP

      jtlo = myByLo(myThid)
      jthi = myByHi(myThid)
      itlo = myBxLo(myThid)
      ithi = myBxHi(myThid)

c--   Initialise local variables.

      do bj = jtlo,jthi
        do bi = itlo,ithi
          objf_local(bi,bj) = 0. _d 0
          num_local(bi,bj) = 0. _d 0
        enddo
      enddo

      call ecco_zero(localdifmean1,Nr,zeroRL,myThid)
      call ecco_zero(localdifmean2,Nr,zeroRL,myThid)

      domean=.FALSE.
      doanom=.FALSE.
      do k2 = 1, NGENPPROC
          if (preproc(k2).EQ.'mean') domean=.TRUE.
          if (preproc(k2).EQ.'anom') doanom=.TRUE.
          if (preproc(k2).EQ.'trend') dotrend=.TRUE.
      enddo

C Extra time loop to compute time-mean fields and costs
      if ( (.NOT. ( localobsfile.EQ.' ' ) )
     &   .AND. ( domean .OR. doanom .OR. dotrend) ) then
        call cost_genloop(
     &     localdifmean1,localdifmean2,.FALSE.,
     &     nnzbar, localbarfile, dummy,
     &     nnzobs, localobsfile, localerrfile,
     &     mult_local, nrecloc, nrecobs,
     &     localstartdate, localperiod,
     &     ylocmask, spminloc, spmaxloc, spzeroloc,
     &     preproc, preproc_c, preproc_i, preproc_r,
     &     posproc, posproc_c, posproc_i, posproc_r,
     &     outlev, outname,
     &     objf_local, num_local,
     &     myIter, myTime, myThid )
      endif

      call ecco_zero(localdifmean1,Nr,zeroRL,myThid)

      if ((.NOT.(localobsfile.EQ.' ')).AND.(.NOT.domean)
     &    .AND.(.NOT.dotrend)) then
        call cost_genloop(
     &     localdifmean2,localdifmean1,.TRUE.,
     &     nnzbar, localbarfile, dummy,
     &     nnzobs, localobsfile, localerrfile,
     &     mult_local, nrecloc, nrecobs,
     &     localstartdate, localperiod,
     &     ylocmask, spminloc, spmaxloc, spzeroloc,
     &     preproc, preproc_c, preproc_i, preproc_r,
     &     posproc, posproc_c, posproc_i, posproc_r,
     &     outlev, outname,
     &     objf_local, num_local,
     &     myIter, myTime, myThid )
      endif

#endif /* ALLOW_ECCO */

      return
      end

C--------------

      subroutine cost_genloop(
     &     localdifmeanIn,localdifmeanOut, addVariaCost,
     &     nnzbar, localbarfile, dummy,
     &     nnzobs, localobsfile, localerrfile,
     &     mult_local, nrecloc, nrecobs,
     &     localstartdate, localperiod,
     &     ylocmask, spminloc, spmaxloc, spzeroloc,
     &     preproc, preproc_c, preproc_i, preproc_r,
     &     posproc, posproc_c, posproc_i, posproc_r,
     &     outlev, outname,
     &     objf_local, num_local,
     &     myIter, myTime, myThid )

C     !DESCRIPTION: \bv
C     Generic routine for evaluating time-dependent
c       cost function contribution
C     \ev

C     !USES:
      implicit none

c     == global variables ==

#include "EEPARAMS.h"
#include "SIZE.h"
#include "PARAMS.h"
#include "GRID.h"
#ifdef ALLOW_CAL
# include "cal.h"
#endif
#ifdef ALLOW_ECCO
# include "ecco.h"
#endif
#ifdef ALLOW_SEAICE
# include "SEAICE_COST.h"
#endif
#ifdef ALLOW_SHELFICE
# include "SHELFICE.h"
#endif

c     == routine arguments ==

      integer myIter
      integer myThid
      integer nnzbar, nnzobs
      integer nrecloc, nrecobs
      integer localstartdate(4)
      integer outlev
      integer preproc_i(NGENPPROC)
      integer posproc_i(NGENPPROC)

      _RL objf_local(nSx,nSy)
      _RL num_local(nSx,nSy)
      _RL dummy
      _RL mult_local
      _RL myTime
      _RL localperiod
      _RL spminloc
      _RL spmaxloc
      _RL spzeroloc
      _RL preproc_r(NGENPPROC)
      _RL posproc_r(NGENPPROC)

      character*(1) ylocmask
      character*(MAX_LEN_FNAM) localbarfile
      character*(MAX_LEN_FNAM) localobsfile
      character*(MAX_LEN_FNAM) localerrfile
      character*(MAX_LEN_FNAM) preproc(NGENPPROC)
      character*(MAX_LEN_FNAM) preproc_c(NGENPPROC)
      character*(MAX_LEN_FNAM) posproc(NGENPPROC)
      character*(MAX_LEN_FNAM) posproc_c(NGENPPROC)
      character*(MAX_LEN_FNAM) outname

      logical addVariaCost
      _RL localdifmeanIn   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localdifmeanOut  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)

#ifdef ALLOW_ECCO

c     == local variables ==

      integer bi,bj
      integer itlo,ithi
      integer jtlo,jthi
      integer irec, jrec
      integer il, k2
      integer localrec, obsrec
      integer nrecloop, nrecclim, k2smooth, k2trend
      logical domean, doanom, dovarwei, doclim, dosmooth, dosumsq
      logical dotrend

      _RL localmask  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)

      _RL localbar   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localweight(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localtmp   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localobs   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localdif   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL difmask    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)

      _RL localdifmsk   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localdifsum   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL localdifnum   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)

      _RL fac
      _RL fac_tmp(N1DDATA)

      character*(128) fname1, fname2, fname3
      character*200 msgbuf
      integer gwunit
      integer ilo, ihi

      logical exst

c     == external functions ==

      integer  ifnblnk, ilnblnk
      external ifnblnk, ilnblnk

CEOP

      call ecco_zero(localbar,Nr,zeroRL,myThid)
      call ecco_zero(localweight,Nr,zeroRL,myThid)
      call ecco_zero(localtmp,Nr,zeroRL,myThid)
      call ecco_zero(localmask,Nr,zeroRL,myThid)

      call ecco_zero(localobs,Nr,zeroRL,myThid)
      call ecco_zero(localdif,Nr,zeroRL,myThid)
      call ecco_zero(difmask,Nr,zeroRL,myThid)

      call ecco_zero(localdifmsk,Nr,zeroRL,myThid)
      call ecco_zero(localdifsum,Nr,zeroRL,myThid)
      call ecco_zero(localdifnum,Nr,zeroRL,myThid)

      do irec = 1, N1DDATA
         fac_tmp(irec) = 0. _d 0 
      enddo
      dotrend=.FALSE.
      dosumsq=.TRUE.
      domean=.FALSE.
      doanom=.FALSE.
      dovarwei=.FALSE.
      dosmooth=.FALSE.
      k2smooth=1
      k2trend = 0
      doclim=.FALSE.
      nrecclim=nrecloc
      fac=oneRL

      do k2 = 1, NGENPPROC
          if (preproc(k2).EQ.'trend') then 
            dotrend=.TRUE.
            k2trend = k2
          endif
          if (preproc(k2).EQ.'mean') domean=.TRUE.
          if (preproc(k2).EQ.'anom') doanom=.TRUE.
          if (preproc(k2).EQ.'variaweight') dovarwei=.TRUE.
          if (preproc(k2).EQ.'nosumsq') dosumsq=.FALSE.
          if (posproc(k2).EQ.'smooth') then
            dosmooth=.TRUE.
            k2smooth=k2
          endif
          if (preproc(k2).EQ.'clim') then
            doclim=.TRUE.
            nrecclim=preproc_i(k2)
          endif
          if (preproc(k2).EQ.'factor') then
            fac=preproc_r(k2)
          endif
      enddo
      if (dotrend .and. (domean .or. doanom .or. dovarwei .or.
     &    doclim)) stop 777

c--   Assign mask
      if ( ylocmask .EQ. 'C' .OR. ylocmask .EQ. 'c' ) then
        call ecco_cprsrl(maskC,nr,localmask,nr,myThid)
      elseif ( ylocmask .EQ. 'S' .OR. ylocmask .EQ. 's' ) then
        call ecco_cprsrl(maskS,nr,localmask,nr,myThid)
      elseif ( ylocmask .EQ. 'W' .OR. ylocmask .EQ. 'w' ) then
        call ecco_cprsrl(maskW,nr,localmask,nr,myThid)
#ifdef ALLOW_SHELFICE
      elseif ( ylocmask .EQ. 'I' .OR. ylocmask .EQ. 'i' ) then
        call ecco_cprsrl(mask2dSHIICF,1,localmask,1,myThid)
#endif
      else
         STOP 'cost_generic: wrong ylocmask'
      endif

c-- set nrecloop to nrecloc
      nrecloop=nrecloc

      if ( dotrend ) then
C
      if ( preproc_c(k2trend) .NE. ' ' ) then
      ilo = ifnblnk(preproc_c(k2trend))
      ihi = ilnblnk(preproc_c(k2trend))

C read in a binary file of the pseudo array (scaled by (nrec-1)). 
      CALL READ_GLVEC_RS( preproc_c(k2trend)(ilo:ihi), ' ', 
     O                    fac_tmp, nrecloc, 1, myThid )

C had some issues for the adjoint if the model reads in an ASCII file here.
C     CALL OPEN_COPY_DATA_FILE(
C    I                          preproc_c(k2trend)(ilo:ihi),
C    I                          'cost_genloop: ',
C    O                          gwunit,
C    I                          myThid )
C     do irec = 1, nrecloc
C        read(gwunit,*) fac_tmp(irec)
C     enddo
C     close(gwunit)

      _BARRIER
      endif

      endif 

c-- reset nrecloop, if needed, according to preproc
      if ( doclim ) nrecloop=MIN(nrecloop,nrecclim)

c--   loop over obsfile records
      do irec = 1, nrecloop

c--     load weights
        exst=.FALSE.
        jrec=1
        if( dovarwei ) jrec = irec
        call cost_gencal(localbarfile, localerrfile,
     &     jrec, localstartdate, localperiod, fname1,
     &     fname3, localrec, obsrec, exst, myThid )
        call ecco_zero(localweight,nnzobs,zeroRL,myThid)
        if ( (localrec .GT. 0).AND.(obsrec .GT. 0).AND.(exst) )
     &  call ecco_readwei(fname3,localweight,localrec,nnzobs,myThid)

c--     determine records and file names
        exst=.FALSE.
        call cost_gencal(localbarfile, localobsfile,
     &     irec, localstartdate, localperiod, fname1,
     &     fname2, localrec, obsrec, exst, myThid )

c--     load model average and observed average
        call ecco_zero(localbar,nnzbar,zeroRL,myThid)
        call cost_genread( fname1, localbar, localtmp, irec, nnzbar,
     &       nrecloc, preproc, preproc_c, preproc_i, preproc_r,
     &       dummy, myThid )
        if( dotrend ) then
          fac = fac_tmp(irec)
          if(preproc_r(k2trend).ne.0) 
     &      fac = fac * preproc_r(k2trend)
        endif
        call ecco_mult(localbar,nnzbar,fac,myThid)

        if (.not.dotrend) then
         call ecco_zero(localobs,nnzobs,spzeroloc,myThid)
         if ( (localrec .GT. 0).AND.(obsrec .GT. 0).AND.(exst) )
     &    CALL READ_REC_3D_RL( fname2, cost_iprec, nnzobs,
     &                         localobs, localrec, 1, myThid )
        else 
         if (irec.eq.1) then
          if ( (localrec .GT. 0).AND.(obsrec .GT. 0).AND.(exst) )
     &    CALL READ_REC_3D_RL( fname2, cost_iprec, nnzobs,
     &                         localobs, irec, 1, myThid )
         endif
        endif

c--     Compute masked model-data difference
        call ecco_diffmsk( localbar, nnzbar, localobs, nnzobs,
     &     localmask, spminloc, spmaxloc, spzeroloc,
     &     localdif, difmask, myThid )

        if ( doanom ) call ecco_subtract( localdifmeanIn,
     &     nnzobs, localdif, nnzobs, myThid )

        if ( domean.OR.doanom.OR.dotrend )
     &    call ecco_addmask(localdif,difmask, nnzobs,localdifsum,
     &    localdifnum, nnzobs,myThid)

        if (addVariaCost) then

#ifdef ALLOW_SMOOTH
        if ( useSMOOTH.AND.dosmooth.AND.
     &     (nnzbar.EQ.1).AND.(nnzobs.EQ.1) )
     &  call smooth_hetero2d(localdif,maskc,
     &     posproc_c(k2smooth),posproc_i(k2smooth),myThid)
#endif

c--     Compute normalized model-obs cost function
        call ecco_addcost(
     I             localdif, localweight, difmask, nnzobs, dosumsq,
     U             objf_local, num_local,
     I             myThid
     &             )
c--     output model-data difference to disk
        if ( outlev.GT.0 ) then
          il=ilnblnk(outname)
          write(fname3(1:128),'(2a)') 'misfit_', outname(1:il)
          if ( nnzobs.EQ.1 ) CALL
     &    WRITE_REC_XY_RL( fname3, localdif,irec, eccoiter, myThid )
          if ( nnzobs.EQ.nr ) CALL
     &    WRITE_REC_XYZ_RL( fname3, localdif,irec, eccoiter, myThid )
        endif

        endif

      enddo
c--   End of loop over obsfile records.

      call ecco_zero(localdifmeanOut,Nr,zeroRL,myThid)
      call ecco_cp(localdifsum,nnzobs,localdifmeanOut,nnzobs,myThid)
      if (.NOT.dotrend)
     & call ecco_divfield(localdifmeanOut,nnzobs,localdifnum,myThid)
      call ecco_cp(localdifnum,nnzobs,localdifmsk,nnzobs,myThid)
      call ecco_divfield(localdifmsk,nnzobs,localdifnum,myThid)

      if ( domean.OR.dotrend ) then
c--     Compute normalized model-obs cost function
        call ecco_addcost(
     I      localdifmeanOut, localweight, localdifmsk, nnzobs, dosumsq,
     U      objf_local, num_local, myThid)

c--     output model-data difference to disk
        if ( outlev.GT.0 ) then
          il=ilnblnk(outname)
          write(fname3(1:128),'(2a)') 'misfit_', outname(1:il)
          if ( nnzobs.EQ.1 ) CALL
     &    WRITE_REC_XY_RL(fname3,localdifmeanOut,1,eccoiter,myThid)
          if ( nnzobs.EQ.nr ) CALL
     &    WRITE_REC_XYZ_RL(fname3,localdifmeanOut,1,eccoiter,myThid)
        endif
      endif
      if ( outlev.GT.1 ) then
          il=ilnblnk(outname)
          write(fname3(1:128),'(2a)') 'weight_', outname(1:il)
          if ( nnzobs.EQ.1 ) CALL
     &    WRITE_REC_XY_RL( fname3, localweight,irec, eccoiter, myThid )
          if ( nnzobs.EQ.nr ) CALL
     &    WRITE_REC_XYZ_RL( fname3, localweight,irec, eccoiter, myThid )
      endif

#endif /* ALLOW_ECCO */

      RETURN
      END
