      SUBROUTINE RETARD(N,FCN,X,Y,XEND,
     &                  RTOL,ATOL,ITOL,
     &                  SOLOUT,IOUT,
     &                  WORK,LWORK,IWORK,LIWORK,LRCONT,LICONT,
     &                  RPAR,IPAR,IDID)
C ----------------------------------------------------------
C     NUMERICAL SOLUTION OF A SYSTEM OF FIRST 0RDER DELAY
C     ORDINARY DIFFERENTIAL EQUATIONS  Y'(X)=F(X,Y(X),Y(X-A),...).
C     THIS CODE IS BASED ON AN EXPLICIT RUNGE-KUTTA METHOD OF   
C     ORDER (4)5 DUE TO DORMAND & PRINCE (WITH STEPSIZE CONTROL
C     AND DENSE OUTPUT).
C
C     AUTHORS: E. HAIRER AND G. WANNER
C              UNIVERSITE DE GENEVE, DEPT. DE MATHEMATIQUES
C              CH-1211 GENEVE 24, SWITZERLAND 
C              E-MAIL:  Ernst.Hairer@math.unige.ch
C                       Gerhard.Wanner@math.unige.ch
C     
C     THIS CODE IS DESCRIBED IN SECTION II.17 OF THE BOOK:
C         E. HAIRER, S.P. NORSETT AND G. WANNER, SOLVING ORDINARY
C         DIFFERENTIAL EQUATIONS I. NONSTIFF PROBLEMS. 2ND EDITION.
C         SPRINGER SERIES IN COMPUTATIONAL MATHEMATICS, 
C         SPRINGER-VERLAG (1993)               
C      
C     VERSION OF SEPTEMBER 30, 1995
C
C     INPUT PARAMETERS  
C     ----------------  
C     N           DIMENSION OF THE SYSTEM 
C
C     FCN         NAME (EXTERNAL) OF SUBROUTINE COMPUTING THE RIGHT-
C                 HAND-SIDE OF THE DELAY EQUATION, E.G.,
C                    SUBROUTINE FCN(N,X,Y,F,RPAR,IPAR)
C                    DOUBLE PRECISION X,Y(N),F(N)
C                    EXTERNAL PHI
C                    F(1)=(1.4D0-YLAG(1,X-1.D0,PHI,RPAR,IPAR))*Y(1)
C                    F(2)=...   ETC.
C                 FOR AN EXPLICATION OF YLAG SEE BELOW.
C                 DO NOT USE YLAG(I,X-0.D0,PHI,RPAR,IPAR) !
C                 THE INITIAL FUNCTION HAS TO BE SUPPLIED BY:
C                    FUNCTION PHI(I,X,RPAR,IPAR)
C                    DOUBLE PRECISION PHI,X
C                 WHERE I IS THE COMPONENT AND X THE ARGUMENT
C
C     X           INITIAL X-VALUE
C
C     Y(N)        INITIAL VALUES FOR Y (MAY BE DIFFERENT FROM PHI (I,X),
C                 IN THIS CASE IT IS HIGHLY RECOMMENDED TO SET IWORK(6)
C                 AND WORK(21),..., SEE BELOW)
C
C     XEND        FINAL X-VALUE (XEND > X)
C
C     RTOL,ATOL   RELATIVE AND ABSOLUTE ERROR TOLERANCES. THEY
C                 CAN BE BOTH SCALARS OR ELSE BOTH VECTORS OF LENGTH N.
C
C     ITOL        SWITCH FOR RTOL AND ATOL:
C                   ITOL=0: BOTH RTOL AND ATOL ARE SCALARS.
C                     THE CODE KEEPS, ROUGHLY, THE LOCAL ERROR OF
C                     Y(I) BELOW RTOL*ABS(Y(I))+ATOL
C                   ITOL=1: BOTH RTOL AND ATOL ARE VECTORS.
C                     THE CODE KEEPS THE LOCAL ERROR OF Y(I) BELOW
C                     RTOL(I)*ABS(Y(I))+ATOL(I).
C
C     SOLOUT      NAME (EXTERNAL) OF SUBROUTINE PROVIDING THE
C                 NUMERICAL SOLUTION DURING INTEGRATION. 
C                 IF IOUT.GE.1, IT IS CALLED AFTER EVERY SUCCESSFUL STEP.
C                 SUPPLY A DUMMY SUBROUTINE IF IOUT=0. 
C                 IT MUST HAVE THE FORM
C                    SUBROUTINE SOLOUT (NR,XOLD,X,Y,N,RPAR,IPAR,IRTRN)
C                    DOUBLE PRECISION X,XOLD,Y(N)
C                    ....  
C                 SOLOUT FURNISHES THE SOLUTION "Y" AT THE NR-TH
C                    GRID-POINT "X" (THEREBY THE INITIAL VALUE IS
C                    THE FIRST GRID-POINT).
C                 "XOLD" IS THE PRECEEDING GRID-POINT.
C                 "IRTRN" SERVES TO INTERRUPT THE INTEGRATION. IF IRTRN
C                    IS SET <0, RETARD WILL RETURN TO THE CALLING PROGRAM.
C           
C          -----  CONTINUOUS OUTPUT: -----
C                 DURING CALLS TO "SOLOUT" AS WELL AS TO "FCN", A
C                 CONTINUOUS SOLUTION IS AVAILABLE THROUGH HTHE FUNCTION
C                        >>>   YLAG(I,S,PHI,RPAR,IPAR)   <<<
C                 WHICH PROVIDES AN APPROXIMATION TO THE I-TH
C                 COMPONENT OF THE SOLUTION AT THE POINT S. THE VALUE S
C                 HAS TO LIE IN AN INTERVAL WHERE THE NUMERICAL SOLUTION
C                 IS ALREADY COMPUTED. IT DEPENDS ON THE SIZE OF LRCONT
C                 (SEE BELOW) HOW FAR BACK THE SOLUTION IS AVAILABLE.
C
C     IOUT        SWITCH FOR CALLING THE SUBROUTINE SOLOUT:
C                    IOUT=0: SUBROUTINE IS NEVER CALLED
C                    IOUT=1: SUBROUTINE IS USED FOR OUTPUT.
C
C     WORK        ARRAY OF WORKING SPACE OF LENGTH "LWORK".
C                 WORK(1),...,WORK(20) SERVE AS PARAMETERS FOR THE CODE.
C                 FOR STANDARD USE, SET THEM TO ZERO BEFORE CALLING.
C                 "LWORK" MUST BE AT LEAST  8*N+21+NGRID
C                 WHERE NGRID=IWORK(6)
C
C     LWORK       DECLARED LENGHT OF ARRAY "WORK".
C
C     IWORK       INTEGER WORKING SPACE OF LENGTH "LIWORK".
C                 IWORK(1),...,IWORK(20) SERVE AS PARAMETERS FOR THE CODE.
C                 FOR STANDARD USE, SET THEM TO ZERO BEFORE CALLING.
C                 "LIWORK" MUST BE AT LEAST 20 .
C
C     LIWORK      DECLARED LENGHT OF ARRAY "IWORK".
C
C     LRCONT      DECLARED LENGTH OF COMMON BLOCK
C                  >>>  COMMON /CORER/RCONT(LRCONT)  <<<
C                 WHICH MUST BE DECLARED IN THE CALLING PROGRAM.
C                 "LRCONT" MUST BE SUFFICIENTLY LARGE. IF THE DENSE    
C                 OUTPUT OF MXST BACK STEPS HAS TO BE STORED, IT MUST 
C                 BE AT LEAST
C                          MXST * ( 5 * NRDENS + 2 )
C                 WHERE NRDENS=IWORK(5) (SEE BELOW).
C
C     LICONT      DECLARED LENGTH OF COMMON BLOCK
C                  >>>  COMMON /COREI/ICONT(LICONT)  <<<
C                 WHICH MUST BE DECLARED IN THE CALLING PROGRAM.
C                 "LICONT" MUST BE AT LEAST
C                              NRDENS + 1
C                 THESE COMMON BLOCKS ARE USED FOR STORING THE COEFFICIENTS
C                 OF THE CONTINUOUS SOLUTION AND MAKES THE CALLING LIST FOR 
C                 THE FUNCTION "CONTD5" AS SIMPLE AS POSSIBLE.
C
C     RPAR, IPAR  REAL AND INTEGER PARAMETERS (OR PARAMETER ARRAYS) WHICH  
C                 CAN BE USED FOR COMMUNICATION BETWEEN YOUR CALLING
C                 PROGRAM AND THE FCN, JAC, MAS, SOLOUT SUBROUTINES. 
C
C-----------------------------------------------------------------------
C 
C     SOPHISTICATED SETTING OF PARAMETERS
C     -----------------------------------
C              SEVERAL PARAMETERS (WORK(1),...,IWORK(1),...) ALLOW
C              TO ADAPT THE CODE TO THE PROBLEM AND TO THE NEEDS OF
C              THE USER. FOR ZERO INPUT, THE CODE CHOOSES DEFAULT VALUES.
C
C    WORK(1)   UROUND, THE ROUNDING UNIT, DEFAULT 2.3D-16.
C
C    WORK(2)   THE SAFETY FACTOR IN STEP SIZE PREDICTION,
C              DEFAULT 0.9D0.
C
C    WORK(3), WORK(4)   PARAMETERS FOR STEP SIZE SELECTION
C              THE NEW STEP SIZE IS CHOSEN SUBJECT TO THE RESTRICTION
C                 WORK(3) <= HNEW/HOLD <= WORK(4)
C              DEFAULT VALUES: WORK(3)=0.2D0, WORK(4)=10.D0
C
C    WORK(5)   IS THE "BETA" FOR STABILIZED STEP SIZE CONTROL (SEE 
C              SECTION IV.2). LARGER VALUES OF BETA (<=0.1) MAKE THE 
C              STEP SIZE CONTROL MORE STABLE. NEGATIVE WORK(5) PROVOKE 
C              BETA=0. DEFAULT (FOR WORK(5)=0.D0) IS WORK(5)=0.04D0.
C
C    WORK(6)   MAXIMAL STEP SIZE, DEFAULT XEND-X.
C
C    WORK(7)   INITIAL STEP SIZE, FOR WORK(7)=0.D0 AN INITIAL GUESS
C              IS COMPUTED WITH HELP OF THE FUNCTION HINIT
C
C    WORK(21),...,WORK(20+NGRID)  PRESCRIBED POINTS, WHICH THE
C              INTEGRATION METHOD HAS TO TAKE AS GRID-POINTS
C              X < WORK(21) < WORK(22) < ... < WORK(20+NGRID) <= XEND
C
C    IWORK(1)  THIS IS THE MAXIMAL NUMBER OF ALLOWED STEPS.
C              THE DEFAULT VALUE (FOR IWORK(1)=0) IS 100000.
C
C    IWORK(2)  SWITCH FOR THE CHOICE OF THE COEFFICIENTS
C              IF IWORK(2).EQ.1  METHOD OF DORMAND AND PRINCE
C              (TABLE 5.2 OF SECTION II.5).
C              AT THE MOMENT THIS IS THE ONLY POSSIBLE CHOICE.
C              THE DEFAULT VALUE (FOR IWORK(2)=0) IS IWORK(2)=1.
C
C    IWORK(3)  SWITCH FOR PRINTING ERROR MESSAGES
C              IF IWORK(3).LT.0 NO MESSAGES ARE BEING PRINTED
C              IF IWORK(3).GT.0 MESSAGES ARE PRINTED WITH
C                 WRITE (IWORK(3),*) ...  
C              DEFAULT VALUE (FOR IWORK(3)=0) IS IWORK(3)=6
C
C    IWORK(4)  TEST FOR STIFFNESS IS ACTIVATED AFTER STEP NUMBER
C              J*IWORK(4) (J INTEGER), PROVIDED IWORK(4).GT.0.
C              FOR NEGATIVE IWORK(4) THE STIFFNESS TEST IS
C              NEVER ACTIVATED; DEFAULT VALUE IS IWORK(4)=1000
C
C    IWORK(5)  = NRDENS = NUMBER OF COMPONENTS, FOR WHICH DENSE OUTPUT
C              IS REQUIRED (EITHER BY "SOLOUT" OR BY "FCN"); 
C              DEFAULT VALUE (FOR IWORK(5)=0) IS IWORK(5)=N;
C              FOR   0 < NRDENS < N   THE COMPONENTS (FOR WHICH DENSE
C              OUTPUT IS REQUIRED) HAVE TO BE SPECIFIED IN
C              ICONT(2),...,ICONT(NRDENS+1);
C              FOR  NRDENS=N  THIS IS DONE BY THE CODE.
C
C    IWORK(6)  = NGRID = NUMBER OF PRESCRIBED POINTS IN THE 
C              INTEGRATION INTERVAL WHICH HAVE TO BE GRID-POINTS
C              IN THE INTEGRATION. USUALLY, AT THESE POINTS THE
C              SOLUTION OR ONE OF ITS DERIVATIVE HAS A DISCONTINUITY.
C              DEFINE THESE POINTS IN WORK(21),...,WORK(20+NGRID)
C              DEFAULT VALUE:  IWORK(6)=0
C
C----------------------------------------------------------------------
C
C     OUTPUT PARAMETERS 
C     ----------------- 
C     X           X-VALUE FOR WHICH THE SOLUTION HAS BEEN COMPUTED
C                 (AFTER SUCCESSFUL RETURN X=XEND).
C
C     Y(N)        NUMERICAL SOLUTION AT X
C 
C     H           PREDICTED STEP SIZE OF THE LAST ACCEPTED STEP
C
C     IDID        REPORTS ON SUCCESSFULNESS UPON RETURN:
C                   IDID= 1  COMPUTATION SUCCESSFUL,
C                   IDID= 2  COMPUT. SUCCESSFUL (INTERRUPTED BY SOLOUT)
C                   IDID=-1  INPUT IS NOT CONSISTENT,
C                   IDID=-2  LARGER NMAX IS NEEDED,
C                   IDID=-3  STEP SIZE BECOMES TOO SMALL.
C                   IDID=-4  PROBLEM IS PROBABLY STIFF (INTERRUPTED).
C                   IDID=-5  COMPUT. INTERRUPTED BY YLAG
C
C   IWORK(17)  NFCN    NUMBER OF FUNCTION EVALUATIONS
C   IWORK(18)  NSTEP   NUMBER OF COMPUTED STEPS
C   IWORK(19)  NACCPT  NUMBER OF ACCEPTED STEPS
C   IWORK(20)  NREJCT  NUMBER OF REJECTED STEPS (DUE TO ERROR TEST),
C                      (STEP REJECTIONS IN THE FIRST STEP ARE NOT COUNTED)
C-----------------------------------------------------------------------
C *** *** *** *** *** *** *** *** *** *** *** *** ***
C          DECLARATIONS 
C *** *** *** *** *** *** *** *** *** *** *** *** ***
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      DIMENSION Y(N),ATOL(*),RTOL(*),WORK(LWORK),IWORK(LIWORK)
      DIMENSION RPAR(*),IPAR(*)
      LOGICAL ARRET
      EXTERNAL FCN,SOLOUT
      COMMON /CORER/RCONT(1) 
      COMMON /COREI/NRDS,ICONT(1)
      COMMON /POSITS/X0BEG,UROUND,HMAX,LAST,IPOS,IRTRN,IDIF,MXST,IPRINT
C *** *** *** *** *** *** ***
C        SETTING THE PARAMETERS 
C *** *** *** *** *** *** ***
      NFCN=0
      NSTEP=0
      NACCPT=0
      NREJCT=0
      ARRET=.FALSE.
C -------- IPRINT FOR MONITORING THE PRINTING
      IF(IWORK(3).EQ.0)THEN
         IPRINT=6
      ELSE
         IPRINT=IWORK(3)
      END IF
C -------- NMAX , THE MAXIMAL NUMBER OF STEPS ----- 
      IF(IWORK(1).EQ.0)THEN
         NMAX=100000
      ELSE
         NMAX=IWORK(1)
         IF(NMAX.LE.0)THEN
            IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &          ' WRONG INPUT IWORK(1)=',IWORK(1)
            ARRET=.TRUE.
         END IF
      END IF
C -------- METH   COEFFICIENTS OF THE METHOD
      IF(IWORK(2).EQ.0)THEN
         METH=1
      ELSE
         METH=IWORK(2)
         IF(METH.LE.0.OR.METH.GE.2)THEN
            IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &          ' CURIOUS INPUT IWORK(2)=',IWORK(2)
            ARRET=.TRUE.
         END IF
      END IF  
C -------- NSTIFF   PARAMETER FOR STIFFNESS DETECTION  
      NSTIFF=IWORK(4) 
      IF (NSTIFF.EQ.0) NSTIFF=1000
      IF (NSTIFF.LT.0) NSTIFF=NMAX+10
C -------- NRDENS   NUMBER OF DENSE OUTPUT COMPONENTS
      NRDENS=IWORK(5)
      IF(NRDENS.LT.0.OR.NRDENS.GT.N)THEN
         IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &           ' CURIOUS INPUT IWORK(5)=',IWORK(5)
         ARRET=.TRUE.
      ELSE
         IF (NRDENS.EQ.0) NRDENS=N
C --------- CONTROL OF LENGTH OF COMMON BLOCK "CORER" -------
         IF(LRCONT.LT.(5*NRDENS+2))THEN
            IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &    ' INSUFFICIENT STORAGE FOR RCONT, MIN. LRCONT=',5*NRDENS+2
            ARRET=.TRUE.
         END IF
C --------- CONTROL OF LENGTH OF COMMON BLOCK "COREI" -------
         IF(LICONT.LT.(NRDENS+1))THEN
            IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &    ' INSUFFICIENT STORAGE FOR ICONT, MIN. LICONT=',NRDENS+1
            ARRET=.TRUE.
         ELSE
            NRDS=NRDENS  
            IF (NRDENS.EQ.N) THEN
                DO 16 I=1,NRDENS
  16            ICONT(I)=I 
            END IF
         END IF
      END IF
C -------- NGRID   NUMBER OF PRESCRIBED GRID-POINTS  
      NGRID=IWORK(6) 
      IF (NGRID.LT.0) NGRID=0
C -------- UROUND   SMALLEST NUMBER SATISFYING 1.D0+UROUND>1.D0  
      IF(WORK(1).EQ.0.D0)THEN
         UROUND=2.3D-16
      ELSE
         UROUND=WORK(1)
         IF(UROUND.LE.1.D-35.OR.UROUND.GE.1.D0)THEN
            IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &        ' WHICH MACHINE DO YOU HAVE? YOUR UROUND WAS:',WORK(1)
            ARRET=.TRUE.
         END IF
      END IF
C -------  SAFETY FACTOR -------------
      IF(WORK(2).EQ.0.D0)THEN
         SAFE=0.9D0
      ELSE
         SAFE=WORK(2)
         IF(SAFE.GE.1.D0.OR.SAFE.LE.1.D-4)THEN
            IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &          ' CURIOUS INPUT FOR SAFETY FACTOR WORK(2)=',WORK(2)
            ARRET=.TRUE.
         END IF
      END IF
C -------  FAC1,FAC2     PARAMETERS FOR STEP SIZE SELECTION
      IF(WORK(3).EQ.0.D0)THEN
         FAC1=0.2D0
      ELSE
         FAC1=WORK(3)
      END IF
      IF(WORK(4).EQ.0.D0)THEN
         FAC2=10.D0
      ELSE
         FAC2=WORK(4)
      END IF
C --------- BETA FOR STEP CONTROL STABILIZATION -----------
      IF(WORK(5).EQ.0.D0)THEN
         BETA=0.04D0
      ELSE
         IF(WORK(5).LT.0.D0)THEN
            BETA=0.D0
         ELSE
            BETA=WORK(5)
            IF(BETA.GT.0.2D0)THEN
               IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &          ' CURIOUS INPUT FOR BETA: WORK(5)=',WORK(5)
            ARRET=.TRUE.
         END IF
         END IF
      END IF
C -------- MAXIMAL STEP SIZE
      IF(WORK(6).EQ.0.D0)THEN
         HMAX=XEND-X
      ELSE
         HMAX=WORK(6)
      END IF
C -------- INITIAL STEP SIZE
      H=WORK(7)
C -------- GRID WITH DISCONTINUITIES
      XURO=100*UROUND*ABS(XEND)
      IF (WORK(20+NGRID)-XEND.GE.XURO) THEN
         IF(IPRINT.GT.0) WRITE(IPRINT,*)
     &          ' WORK(20+NGRID) HAS TO BE <= XEND'
         ARRET=.TRUE.
      END IF
      IF (ABS(WORK(20+NGRID)-XEND).GE.XURO) NGRID=NGRID+1
      WORK(20+NGRID)=XEND
C ------- PREPARE THE ENTRY-POINTS FOR THE ARRAYS IN WORK -----
      IEGR=21
      IEY1=IEGR+NGRID
      IEK1=IEY1+N
      IEK2=IEK1+N
      IEK3=IEK2+N
      IEK4=IEK3+N
      IEK5=IEK4+N
      IEK6=IEK5+N
      IEYS=IEK6+N
C ------ TOTAL STORAGE REQUIREMENT -----------
      ISTORE=IEYS+N-1
      IF(ISTORE.GT.LWORK)THEN
        IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &   ' INSUFFICIENT STORAGE FOR WORK, MIN. LWORK=',ISTORE
        ARRET=.TRUE.
      END IF
      ISTORE=20
      IF(ISTORE.GT.LIWORK)THEN
        IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &   ' INSUFFICIENT STORAGE FOR IWORK, MIN. LIWORK=',ISTORE
        ARRET=.TRUE.
      END IF
C ------ WHEN A FAIL HAS OCCURED, WE RETURN WITH IDID=-1
      IF (ARRET) THEN
         IDID=-1
         RETURN
      END IF
C -------- CALL TO CORE INTEGRATOR ------------
      IDIF=5*NRDENS+2
      MXST=LRCONT/IDIF
      CALL RETCOR(N,FCN,X,Y,XEND,H,RTOL,ATOL,ITOL,SOLOUT,IOUT,
     &   IDID,NMAX,METH,NSTIFF,SAFE,BETA,FAC1,FAC2,NGRID,
     &   WORK(IEY1),WORK(IEK1),WORK(IEK2),WORK(IEK3),WORK(IEK4),
     &   WORK(IEK5),WORK(IEK6),WORK(IEYS),WORK(IEGR),
     &   RPAR,IPAR,NFCN,NSTEP,NACCPT,NREJCT)
      WORK(7)=H
      IWORK(17)=NFCN
      IWORK(18)=NSTEP
      IWORK(19)=NACCPT
      IWORK(20)=NREJCT
C ----------- RETURN -----------
      RETURN
      END
C
C
C
C  ----- ... AND HERE IS THE CORE INTEGRATOR  ----------
C
      SUBROUTINE RETCOR(N,FCN,X,Y,XEND,H,RTOL,ATOL,ITOL,SOLOUT,IOUT,
     &   IDID,NMAX,METH,NSTIFF,SAFE,BETA,FAC1,FAC2,NGRID,Y1,K1,K2,K3,
     &   K4,K5,K6,YSTI,GRID,RPAR,IPAR,NFCN,NSTEP,NACCPT,NREJCT)
C ----------------------------------------------------------
C     CORE INTEGRATOR FOR RETARD
C     PARAMETERS SAME AS IN RETARD WITH WORKSPACE ADDED 
C ---------------------------------------------------------- 
C         DECLARATIONS 
C ---------------------------------------------------------- 
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      DOUBLE PRECISION Y(N),Y1(N),K1(N),K2(N),K3(N),K4(N),K5(N),K6(N)
      DIMENSION GRID(NGRID),YSTI(N)
      DIMENSION ATOL(*),RTOL(*),RPAR(*),IPAR(*)
      LOGICAL REJECT,LAST 
      EXTERNAL FCN
      COMMON /CORER/CONT(1) 
      COMMON /COREI/NRD,ICOMP(1)
      COMMON /POSITS/X0BEG,UROUND,HMAX,IACT,IPOS,IRTRN,IDIF,MXST,IPRINT
C *** *** *** *** *** *** ***
C  INITIALISATIONS
C *** *** *** *** *** *** *** 
      IF (METH.EQ.1) CALL CDOPRI(C2,C3,C4,C5,E1,E3,E4,E5,E6,E7,
     &                    A21,A31,A32,A41,A42,A43,A51,A52,A53,A54,
     &                    A61,A62,A63,A64,A65,A71,A73,A74,A75,A76,
     &                    D1,D3,D4,D5,D6,D7)
      FACOLD=1.D-4  
      EXPO1=0.2D0-BETA*0.75D0
      FACC1=1.D0/FAC1
      FACC2=1.D0/FAC2
      POSNEG=SIGN(1.D0,XEND-X)  
C --- INITIAL PREPARATIONS   
      IACT=1
      IPOS=1
      X0BEG=X
      XEND=GRID(1)
      IGRID=1
      UROUND=10*UROUND
      DO 3 I=0,MXST-1
  3      CONT(1+IDIF*I)=X
      ATOLI=ATOL(1)
      RTOLI=RTOL(1)    
      LAST=.FALSE. 
      HLAMB=0.D0
      IASTI=0
      HMAX=ABS(HMAX)     
      IRTRN=2
      CALL FCN(N,X,Y,K1,RPAR,IPAR)
      IRTRN=1
      IORD=5  
      IF (H.EQ.0.D0) H=HINIT(N,FCN,X,Y,XEND,POSNEG,K1,K2,K3,IORD,
     &                       HMAX,ATOL,RTOL,ITOL,RPAR,IPAR)
      NFCN=NFCN+2
      REJECT=.FALSE.
      XOLD=X
      IF (IOUT.NE.0) THEN 
          CALL SOLOUT(NACCPT+1,XOLD,X,Y,N,RPAR,IPAR,IRTRN)
          IF (IRTRN.LT.0) GOTO 79
      END IF
C --- BASIC INTEGRATION STEP  
   1  CONTINUE
      IF (NSTEP.GT.NMAX) GOTO 78
      IF (ABS(H).LE.ABS(X)*UROUND)GOTO 77
      IF ((X+1.01D0*H-XEND)*POSNEG.GT.0.D0) THEN
         H=XEND-X 
         LAST=.TRUE.
      ELSE
         IF ((X+1.8D0*H-XEND)*POSNEG.GT.0.D0) H=(XEND-X)*0.55D0
      END IF
      NSTEP=NSTEP+1
C --- THE FIRST 6 STAGES
      DO 22 I=1,N 
  22  Y1(I)=Y(I)+H*A21*K1(I)
      CALL FCN(N,X+C2*H,Y1,K2,RPAR,IPAR)
      DO 23 I=1,N 
  23  Y1(I)=Y(I)+H*(A31*K1(I)+A32*K2(I))
      CALL FCN(N,X+C3*H,Y1,K3,RPAR,IPAR)
      DO 24 I=1,N 
  24  Y1(I)=Y(I)+H*(A41*K1(I)+A42*K2(I)+A43*K3(I))
      CALL FCN(N,X+C4*H,Y1,K4,RPAR,IPAR)
      DO 25 I=1,N 
  25  Y1(I)=Y(I)+H*(A51*K1(I)+A52*K2(I)+A53*K3(I)+A54*K4(I))
      CALL FCN(N,X+C5*H,Y1,K5,RPAR,IPAR) 
      DO 26 I=1,N 
  26  YSTI(I)=Y(I)+H*(A61*K1(I)+A62*K2(I)+A63*K3(I)+A64*K4(I)+A65*K5(I))
      XPH=X+H
      CALL FCN(N,XPH,YSTI,K6,RPAR,IPAR)
      DO 27 I=1,N 
  27  Y1(I)=Y(I)+H*(A71*K1(I)+A73*K3(I)+A74*K4(I)+A75*K5(I)+A76*K6(I))  
      IRTRN=1
      CALL FCN(N,XPH,Y1,K2,RPAR,IPAR)
C ------  PREPARE DENSE OUTPUT
            NRDL=4*NRD+IACT
            DO 40 J=1,NRD
            I=ICOMP(J)
            CONT(NRDL+J)=H*(D1*K1(I)+D3*K3(I)+D4*K4(I)+D5*K5(I)
     &                   +D6*K6(I)+D7*K2(I)) 
  40        CONTINUE
C -------
      DO 28 I=1,N 
  28  K4(I)=(E1*K1(I)+E3*K3(I)+E4*K4(I)+E5*K5(I)+E6*K6(I)+E7*K2(I))*H
      NFCN=NFCN+6 
C ------ ERROR ESTIMATION  
      ERR=0.D0
      IF (ITOL.EQ.0) THEN   
        DO 41 I=1,N 
        SK=ATOLI+RTOLI*MAX(ABS(Y(I)),ABS(Y1(I)))
  41    ERR=ERR+(K4(I)/SK)**2
      ELSE
        DO 42 I=1,N 
        SK=ATOL(I)+RTOL(I)*MAX(ABS(Y(I)),ABS(Y1(I)))
  42    ERR=ERR+(K4(I)/SK)**2
      END IF
      ERR=SQRT(ERR/N)  
C --- COMPUTATION OF HNEW
      FAC11=ERR**EXPO1
C --- LUND-STABILIZATION
      FAC=FAC11/FACOLD**BETA
C --- WE REQUIRE  FAC1 <= HNEW/H <= FAC2
      FAC=MAX(FACC2,MIN(FACC1,FAC/SAFE))
      HNEW=H/FAC  
      IF(ERR.LE.1.D0)THEN
C --- STEP IS ACCEPTED  
         FACOLD=MAX(ERR,1.0D-4)
         NACCPT=NACCPT+1
C ------- STIFFNESS DETECTION
         IF (MOD(NACCPT,NSTIFF).EQ.0.OR.IASTI.GT.0) THEN
            STNUM=0.D0
            STDEN=0.D0
            DO 64 I=1,N 
               STNUM=STNUM+(K2(I)-K6(I))**2
               STDEN=STDEN+(Y1(I)-YSTI(I))**2
 64         CONTINUE  
            IF (STDEN.GT.0.D0) HLAMB=H*SQRT(STNUM/STDEN) 
            IF (HLAMB.GT.3.25D0) THEN
               NONSTI=0
               IASTI=IASTI+1  
               IF (IASTI.EQ.15) THEN
                  IF (IPRINT.GT.0) WRITE (IPRINT,*) 
     &               ' THE PROBLEM SEEMS TO BECOME STIFF AT X = ',X   
                  IF (IPRINT.LE.0) GOTO 76
               END IF
            ELSE
               NONSTI=NONSTI+1  
               IF (NONSTI.EQ.6) IASTI=0
            END IF
         END IF 
C -------   COMPUTE DENSE OUTPUT
            DO 43 J=1,NRD
            I=ICOMP(J)
            YDIFF=Y1(I)-Y(I)
            BSPL=H*K1(I)-YDIFF 
            CONT(IACT+J)=Y(I)
            CONT(IACT+NRD+J)=YDIFF
            CONT(IACT+2*NRD+J)=BSPL
            CONT(IACT+3*NRD+J)=-H*K2(I)+YDIFF-BSPL
  43        CONTINUE
            CONT(IACT)=X
            IACT=IACT+IDIF
            CONT(IACT-1)=H
            IF (IACT+IDIF-1.GT.MXST*IDIF) IACT=1
C ------
         DO 44 I=1,N
         K1(I)=K2(I)
  44     Y(I)=Y1(I)
         XOLD=X
         X=XPH
         IF (IRTRN.EQ.3) THEN
            IRTRN=4
            CALL FCN(N,X,Y,K1,RPAR,IPAR)
            NFCN=NFCN+1
            IRTRN=1
         END IF
         IF (IOUT.NE.0) THEN
            CALL SOLOUT(NACCPT+1,XOLD,X,Y,N,RPAR,IPAR,IRTRN)
            IF (IRTRN.LT.0) GOTO 79
         END IF 
C ------- NORMAL EXIT
         IF (LAST) THEN
            IF (IGRID.EQ.NGRID) THEN
               H=HNEW
               IDID=1
               RETURN
            ELSE
               IGRID=IGRID+1
               LAST=.FALSE.
               XEND=GRID(IGRID)
               HNEW=0.9D0*HNEW
            END IF
         END IF
         IF(ABS(HNEW).GT.HMAX)HNEW=POSNEG*HMAX  
         IF(REJECT)HNEW=POSNEG*MIN(ABS(HNEW),ABS(H))
         REJECT=.FALSE. 
      ELSE  
C --- STEP IS REJECTED   
         IF (IRTRN.LT.0) GOTO 79
         HNEW=H/MIN(FACC1,FAC11/SAFE)
         REJECT=.TRUE.  
         IF(NACCPT.GE.1)NREJCT=NREJCT+1   
         LAST=.FALSE.
      END IF
      H=HNEW
      IF (IRTRN.LT.0) GOTO 75
      GOTO 1
C --- FAIL EXIT
  75  CONTINUE
      IDID=-5
      RETURN
  76  CONTINUE
      IDID=-4
      RETURN
  77  CONTINUE
      IF (IPRINT.GT.0) WRITE(IPRINT,979)X   
      IF (IPRINT.GT.0) WRITE(IPRINT,*)' STEP SIZE T0O SMALL, H=',H
      IDID=-3
      RETURN
  78  CONTINUE
      IF (IPRINT.GT.0) WRITE(IPRINT,979)X   
      IF (IPRINT.GT.0) WRITE(IPRINT,*)
     &     ' MORE THAN NMAX =',NMAX,'STEPS ARE NEEDED' 
      IDID=-2
      RETURN
  79  CONTINUE
      IF (IPRINT.GT.0) WRITE(IPRINT,979)X
 979  FORMAT(' EXIT OF RETARD AT X=',E18.4) 
      IDID=2
      RETURN
      END
C
      FUNCTION HINIT(N,FCN,X,Y,XEND,POSNEG,F0,F1,Y1,IORD,
     &                       HMAX,ATOL,RTOL,ITOL,RPAR,IPAR)
C ----------------------------------------------------------
C ----  COMPUTATION OF AN INITIAL STEP SIZE GUESS
C ----------------------------------------------------------
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      DIMENSION Y(N),Y1(N),F0(N),F1(N),ATOL(*),RTOL(*)
      DIMENSION RPAR(*),IPAR(*)
C ---- COMPUTE A FIRST GUESS FOR EXPLICIT EULER AS
C ----   H = 0.01 * NORM (Y0) / NORM (F0)
C ---- THE INCREMENT FOR EXPLICIT EULER IS SMALL
C ---- COMPARED TO THE SOLUTION
      DNF=0.0D0
      DNY=0.0D0 
      ATOLI=ATOL(1)
      RTOLI=RTOL(1)    
      IF (ITOL.EQ.0) THEN   
        DO 10 I=1,N 
        SK=ATOLI+RTOLI*ABS(Y(I))
        DNF=DNF+(F0(I)/SK)**2
  10    DNY=DNY+(Y(I)/SK)**2 
      ELSE
        DO 11 I=1,N 
        SK=ATOL(I)+RTOL(I)*ABS(Y(I))
        DNF=DNF+(F0(I)/SK)**2
  11    DNY=DNY+(Y(I)/SK)**2 
      END IF
      IF (DNF.LE.1.D-10.OR.DNY.LE.1.D-10) THEN
         H=1.0D-6
      ELSE
         H=SQRT(DNY/DNF)*0.01D0 
      END IF
      H=MIN(H,HMAX)
      H=SIGN(H,POSNEG) 
C ---- PERFORM AN EXPLICIT EULER STEP
      DO 12 I=1,N
  12  Y1(I)=Y(I)+H*F0(I)
      CALL FCN(N,X+H,Y1,F1,RPAR,IPAR) 
C ---- ESTIMATE THE SECOND DERIVATIVE OF THE SOLUTION
      DER2=0.0D0
      IF (ITOL.EQ.0) THEN   
        DO 15 I=1,N 
        SK=ATOLI+RTOLI*ABS(Y(I))
  15    DER2=DER2+((F1(I)-F0(I))/SK)**2   
      ELSE
        DO 16 I=1,N 
        SK=ATOL(I)+RTOL(I)*ABS(Y(I))
  16    DER2=DER2+((F1(I)-F0(I))/SK)**2   
      END IF
      DER2=SQRT(DER2)/H
C ---- STEP SIZE IS COMPUTED SUCH THAT
C ----  H**IORD * MAX ( NORM (F0), NORM (DER2)) = 0.01
      DER12=MAX(ABS(DER2),SQRT(DNF))
      IF (DER12.LE.1.D-15) THEN
         H1=MAX(1.0D-6,ABS(H)*1.0D-3)
      ELSE
         H1=(0.01D0/DER12)**(1.D0/IORD) 
      END IF
      H=MIN(100*H,H1,HMAX)
      HINIT=SIGN(H,POSNEG)  
      RETURN
      END 
C
      FUNCTION YLAG(II,X,PHI,RPAR,IPAR)
C ----------------------------------------------------------
C     THIS FUNCTION CAN BE USED FOR CONINUOUS OUTPUT IN CONECTION
C     WITH THE OUTPUT-SUBROUTINE FOR RETARD. IT PROVIDES AN
C     APPROXIMATION TO THE I-TH COMPONENT OF THE SOLUTION AT X.
C ----------------------------------------------------------
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      DIMENSION RPAR(*),IPAR(*)
      COMMON /CORER/CON(1) 
      COMMON /COREI/ND,ICOMP(1)
      COMMON /POSITS/X0,UR4,HMAX,IACT,IPOS,IRTRN,IDIF,MXST,IPRINT
C ----- INITIAL PHASE
      COMPAR=UR4*MAX(ABS(X),ABS(X0))
         IF (X-X0.LE.COMPAR) THEN
            IF (IRTRN.LE.3) THEN
               YLAG=PHI(II,X,RPAR,IPAR)  
               IF (IRTRN.EQ.2) HMAX=MIN(HMAX,X0-X)
               IF (X0-X.LE.COMPAR) IRTRN=3
               RETURN
            ELSE
               IF (X0-X.GT.COMPAR) THEN
                  YLAG=PHI(II,X,RPAR,IPAR)  
                  RETURN
               END IF
            END IF
         END IF
C ----- COMPUTE PLACE OF II-TH COMPONENT 
      I=0 
      DO 5 J=1,ND 
      IF (ICOMP(J).EQ.II) I=J
   5  CONTINUE
      IF (I.EQ.0) THEN
         IF (IPRINT.GT.0) WRITE (IPRINT,*) 
     &           ' NO DENSE OUTPUT AVAILABLE FOR COMP.',II 
         RETURN
      END IF  
C ----- COMPUTE THE POSITION OF X
      IF (X-CON(IACT).LT.-COMPAR) THEN  
         IF (IPRINT.GT.0) WRITE (IPRINT,*) 
     &          ' MEMORY FULL, MXST = ',MXST
         IRTRN=-1
         RETURN
      END IF
      INEXT=IACT-IDIF
      IF (INEXT.LT.1) INEXT=(MXST-1)*IDIF+1
      XRIGHT=CON(INEXT)+CON(INEXT+IDIF-1)  
      IF (X-XRIGHT.GT.UR4*MAX(ABS(X),ABS(XRIGHT))) THEN  
         IF (IPRINT.GT.0) WRITE (IPRINT,*) 
     &          ' DONT USE ADVANCED ARGUMENTS '
         IRTRN=-1
         RETURN
      END IF
   1  CONTINUE 
      IF (X-CON(IPOS).LT.-COMPAR) THEN
         IPOS=IPOS-IDIF
         IF (IPOS.LT.1) IPOS=(MXST-1)*IDIF+1
         GOTO 1
      END IF
   2  CONTINUE
      INEXT=IPOS+IDIF
      IF (INEXT.GT.(MXST-1)*IDIF+1) INEXT=1
      IF (X.GT.CON(INEXT).AND.INEXT.NE.IACT) THEN 
         IPOS=INEXT 
         GOTO 2
      END IF
C ----- COMPUTE DESIRED APPROXIMATION
      THETA=(X-CON(IPOS))/CON(IPOS+IDIF-1)
      THETA1=1.D0-THETA
      I=I+IPOS
      YLAG=CON(I)+THETA*(CON(ND+I)+THETA1*(CON(2*ND+I)+THETA*
     &           (CON(3*ND+I)+THETA1*CON(4*ND+I))))
      RETURN
      END
C
      SUBROUTINE CDOPRI(C2,C3,C4,C5,E1,E3,E4,E5,E6,E7,
     &                    A21,A31,A32,A41,A42,A43,A51,A52,A53,A54,
     &                    A61,A62,A63,A64,A65,A71,A73,A74,A75,A76,
     &                    D1,D3,D4,D5,D6,D7)
C ----------------------------------------------------------
C     RUNGE-KUTTA COEFFICIENTS OF DORMAND AND PRINCE (1980)
C ----------------------------------------------------------
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      C2=0.2D0
      C3=0.3D0
      C4=0.8D0
      C5=8.D0/9.D0
      A21=0.2D0
      A31=3.D0/40.D0
      A32=9.D0/40.D0
      A41=44.D0/45.D0
      A42=-56.D0/15.D0
      A43=32.D0/9.D0
      A51=19372.D0/6561.D0
      A52=-25360.D0/2187.D0
      A53=64448.D0/6561.D0
      A54=-212.D0/729.D0
      A61=9017.D0/3168.D0
      A62=-355.D0/33.D0
      A63=46732.D0/5247.D0
      A64=49.D0/176.D0
      A65=-5103.D0/18656.D0
      A71=35.D0/384.D0
      A73=500.D0/1113.D0
      A74=125.D0/192.D0
      A75=-2187.D0/6784.D0
      A76=11.D0/84.D0
      E1=71.D0/57600.D0
      E3=-71.D0/16695.D0
      E4=71.D0/1920.D0
      E5=-17253.D0/339200.D0
      E6=22.D0/525.D0
      E7=-1.D0/40.D0  
C ---- DENSE OUTPUT OF SHAMPINE (1986)
      D1=-12715105075.D0/11282082432.D0
      D3=87487479700.D0/32700410799.D0
      D4=-10690763975.D0/1880347072.D0
      D5=701980252875.D0/199316789632.D0
      D6=-1453857185.D0/822651844.D0
      D7=69997945.D0/29380423.D0
      RETURN
      END

