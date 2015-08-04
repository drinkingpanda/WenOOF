module type_weno_interpolator_upwind
!-----------------------------------------------------------------------------------------------------------------------------------
!< Upwind biased WENO interpolator object,
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
use type_weno_interpolator
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
implicit none
private
save
public :: weno_interpolator_upwind, weno_constructor_upwind
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
type, extends(weno_constructor) :: weno_constructor_upwind
  integer :: S = 0 !< Stencils dimension.
endtype weno_constructor_upwind
interface weno_constructor_upwind
  procedure weno_constructor_upwind_init
endinterface

type, extends(weno_interpolator) :: weno_interpolator_upwind
  private
  integer           :: S = 0              !< Stencil dimension.
  real              :: eps = 1.E-16       !< Parameter for avoiding divided by zero when computing smoothness indicators.
  real, allocatable :: weights_opt(:,:)   !< Optimal weights                    [1:2,0:S-1].
  real, allocatable :: poly_coef(:,:,:)   !< Polynomials coefficients           [1:2,0:S-1,0:S-1].
  real, allocatable :: smooth_coef(:,:,:) !< Smoothness indicators coefficients [0:S-1,0:S-1,0:S-1].
  contains
    ! public methods
    procedure, public :: destroy
    procedure, public :: create
    procedure, public :: description
    procedure, public :: interpolate
    ! private methods
    final :: finalize
endtype weno_interpolator_upwind
!-----------------------------------------------------------------------------------------------------------------------------------
contains
  ! weno_constructor_upwind
  elemental function  weno_constructor_upwind_init(S) result(constructor)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Destoy the WENO interpolator.
  !---------------------------------------------------------------------------------------------------------------------------------
  integer, intent(IN)           :: S           !< Stencils dimension.
  type(weno_constructor_upwind) :: constructor !<WENO constructor.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  constructor%S = S
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction  weno_constructor_upwind_init

  ! weno_interpolator_upwind
  ! public methods
  elemental subroutine destroy(self)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Destoy the WENO interpolator.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(weno_interpolator_upwind), intent(INOUT) :: self !< WENO interpolator.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  self%S = 0
  self%eps = 1.E-16
  if (allocated(self%weights_opt)) deallocate(self%weights_opt)
  if (allocated(self%poly_coef  )) deallocate(self%poly_coef  )
  if (allocated(self%smooth_coef)) deallocate(self%smooth_coef)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine destroy

  subroutine create(self, constructor)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Create the WENO interpolator.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(weno_interpolator_upwind), intent(INOUT) :: self        !< WENO interpolator.
  class(weno_constructor),         intent(IN)    :: constructor !< WENO constructor.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  select type(constructor)
  type is(weno_constructor_upwind)
    call self%destroy
    self%S = constructor%S
    allocate(self%weights_opt(1:2, 0:self%S - 1))
    allocate(self%poly_coef(1:2, 0:self%S - 1, 0:self%S - 1))
    allocate(self%smooth_coef(0:self%S - 1, 0:self%S - 1, 0:self%S - 1))
    call set_weights_optimal
    call set_polynomial_coefficients
    call set_smoothness_indicators_coefficients
  endselect
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  contains
    subroutine set_weights_optimal()
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Set the values of optimial weights.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    select case(self%S)
    case(2) ! 3rd order
      ! 1 => left interface (i-1/2)
      self%weights_opt(1, 0) = 2./3. ! stencil 0
      self%weights_opt(1, 1) = 1./3. ! stencil 1
      ! 2 => right interface (i+1/2)
      self%weights_opt(2, 0) = 1./3. ! stencil 0
      self%weights_opt(2, 1) = 2./3. ! stencil 1
    case(3) ! 5th order
      ! 1 => left interface (i-1/2)
      self%weights_opt(1, 0) = 0.3 ! stencil 0
      self%weights_opt(1, 1) = 0.6 ! stencil 1
      self%weights_opt(1, 2) = 0.1 ! stencil 2
      ! 2 => right interface (i+1/2)
      self%weights_opt(2, 0) = 0.1 ! stencil 0
      self%weights_opt(2, 1) = 0.6 ! stencil 1
      self%weights_opt(2, 2) = 0.3 ! stencil 2
    case(4) ! 7th order
      ! 1 => left interface (i-1/2)
      self%weights_opt(1, 0) =  4./35. ! stencil 0
      self%weights_opt(1, 1) = 18./35. ! stencil 1
      self%weights_opt(1, 2) = 12./35. ! stencil 2
      self%weights_opt(1, 3) =  1./35. ! stencil 3
      ! 2 => right interface (i+1/2)
      self%weights_opt(2, 0) =  1./35. ! stencil 0
      self%weights_opt(2, 1) = 12./35. ! stencil 1
      self%weights_opt(2, 2) = 18./35. ! stencil 2
      self%weights_opt(2, 3) =  4./35. ! stencil 3
    endselect
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endsubroutine set_weights_optimal

    subroutine set_polynomial_coefficients()
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Set the values of polynomial_coefficient.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    associate(coef => self%poly_coef)
      select case(self%S)
      case(2) ! 3rd order
        ! 1 => left interface (i-1/2)
        !  cell  0           ;    cell  1
        coef(1, 0, 0) =  0.5 ; coef(1, 1, 0) =  0.5 ! stencil 0
        coef(1, 0, 1) = -0.5 ; coef(1, 1, 1) =  1.5 ! stencil 1
        ! 2 => right interface (i+1/2)
        !  cell  0           ;    cell  1
        coef(2, 0, 0) =  1.5 ; coef(2, 1, 0) = -0.5 ! stencil 0
        coef(2, 0, 1) =  0.5 ; coef(2, 1, 1) =  0.5 ! stencil 1
      case(3) ! 5th order
        ! 1 => left interface (i-1/2)
        !  cell  0             ;    cell  1             ;    cell  2
        coef(1, 0, 0) =  1./3. ; coef(1, 1, 0) =  5./6. ; coef(1, 2, 0) = -1./6. ! stencil 0
        coef(1, 0, 1) = -1./6. ; coef(1, 1, 1) =  5./6. ; coef(1, 2, 1) =  1./3. ! stencil 1
        coef(1, 0, 2) =  1./3. ; coef(1, 1, 2) = -7./6. ; coef(1, 2, 2) = 11./6. ! stencil 2
        ! 2 => right interface (i+1/2)
        !  cell  0             ;    cell  1             ;    cell  2
        coef(2, 0, 0) = 11./6. ; coef(2, 1, 0) = -7./6. ; coef(2, 2, 0) =  1./3. ! stencil 0
        coef(2, 0, 1) =  1./3. ; coef(2, 1, 1) =  5./6. ; coef(2, 2, 1) = -1./6. ! stencil 1
        coef(2, 0, 2) = -1./6. ; coef(2, 1, 2) =  5./6. ; coef(2, 2, 2) =  1./3. ! stencil 2
      case(4) ! 7th order
        ! 1 => left interface (i-1/2)
        !  cell  0              ;   cell  1               ;   cell  2                ;   cell  3
        coef(1, 0, 0) =  1./4.  ; coef(1, 1, 0) = 13./12. ; coef(1, 2, 0) =  -5./12. ; coef(1, 3, 0) =  1./12. ! sten 0
        coef(1, 0, 1) = -1./12. ; coef(1, 1, 1) =  7./12. ; coef(1, 2, 1) =   7./12. ; coef(1, 3, 1) = -1./12. ! sten 1
        coef(1, 0, 2) =  1./12. ; coef(1, 1, 2) = -5./12. ; coef(1, 2, 2) =  13./12. ; coef(1, 3, 2) =  1./4.  ! sten 2
        coef(1, 0, 3) = -1./4.  ; coef(1, 1, 3) = 13./12. ; coef(1, 2, 3) = -23./12. ; coef(1, 3, 3) = 25./12. ! sten 3
        ! 2 => right interface (i+1/2)
        !  cell  0              ;   cell  1                ;   cell  2               ;   cell  3
        coef(2, 0, 0) = 25./12. ; coef(2, 1, 0) = -23./12. ; coef(2, 2, 0) = 13./12. ; coef(2, 3, 0) = -1./4.  ! sten 0
        coef(2, 0, 1) =  1./4.  ; coef(2, 1, 1) =  13./12. ; coef(2, 2, 1) = -5./12. ; coef(2, 3, 1) =  1./12. ! sten 1
        coef(2, 0, 2) = -1./12. ; coef(2, 1, 2) =   7./12. ; coef(2, 2, 2) =  7./12. ; coef(2, 3, 2) = -1./12. ! sten 2
        coef(2, 0, 3) =  1./12. ; coef(2, 1, 3) =  -5./12. ; coef(2, 2, 3) = 13./12. ; coef(2, 3, 3) =  1./4.  ! sten 3
      endselect
    endassociate
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endsubroutine set_polynomial_coefficients

    subroutine set_smoothness_indicators_coefficients()
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Set the values of smoothness indicators coefficients.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    associate(coef => self%smooth_coef)
      select case(self%S)
      case(2) ! 3rd order
        ! stencil 0
        !      i*i         ;       (i-1)*i
        coef(0, 0, 0) = 1. ; coef(1, 0, 0) = -2.
        !      /           ;       (i-1)*(i-1)
        coef(0, 1, 0) = 0. ; coef(1, 1, 0) = 1.
        ! stencil 1
        !     (i+1)*(i+1)  ;       (i+1)*i
        coef(0, 0, 1) = 1. ; coef(1, 0, 1) = -2.
        !      /           ;        i*i
        coef(0, 1, 1) = 0. ; coef(1, 1, 1) = 1.
      case(3) ! 5th order
        ! stencil 0
        !      i*i              ;       (i-1)*i           ;       (i-2)*i
        coef(0, 0, 0) =  10./3. ; coef(1, 0, 0) = -31./3. ; coef(2, 0, 0) =  11./3.
        !      /                ;       (i-1)*(i-1)       ;       (i-2)*(i-1)
        coef(0, 1, 0) =   0.    ; coef(1, 1, 0) =  25./3. ; coef(2, 1, 0) = -19./3.
        !      /                ;        /                ;       (i-2)*(i-2)
        coef(0, 2, 0) =   0.    ; coef(1, 2, 0) =   0.    ; coef(2, 2, 0) =   4./3.
        ! stencil 1
        !     (i+1)*(i+1)       ;        i*(i+1)          ;       (i-1)*(i+1)
        coef(0, 0, 1) =   4./3. ; coef(1, 0, 1) = -13./3. ; coef(2, 0, 1) =   5./3.
        !      /                ;        i*i              ;       (i-1)*i
        coef(0, 1, 1) =   0.    ; coef(1, 1, 1) =  13./3. ; coef(2, 1, 1) = -13./3.
        !      /                ;        /                ;       (i-1)*(i-1)
        coef(0, 2, 1) =   0.    ; coef(1, 2, 1) =   0.    ; coef(2, 2, 1) =   4./3.
        ! stencil 2
        !     (i+2)*(i+2)       ;       (i+1)*(i+2)       ;        i*(i+2)
        coef(0, 0, 2) =   4./3. ; coef(1, 0, 2) = -19./3. ; coef(2, 0, 2) =  11./3.
        !      /                ;       (i+1)*(i+1)       ;        i*(i+1)
        coef(0, 1, 2) =   0.    ; coef(1, 1, 2) =  25./3. ; coef(2, 1, 2) = -31./3.
        !      /                ;        /                ;        i*i
        coef(0, 2, 2) =   0.    ; coef(1, 2, 2) =   0.    ; coef(2, 2, 2) =  10./3.
      case(4) ! 7th order
        ! stencil 0
        !      i*i            ;       (i-1)*i         ;       (i-2)*i          ;       (i-3)*i
        coef(0, 0, 0) = 2107. ; coef(1, 0, 0) =-9402. ; coef(2, 0, 0) = 7042.  ; coef(3, 0, 0) = -1854.
        !      /              ;       (i-1)*(i-1)     ;       (i-2)*(i-1)      ;       (i-3)*(i-1)
        coef(0, 1, 0) =   0.  ; coef(1, 1, 0) =11003. ; coef(2, 1, 0) =-17246. ; coef(3, 1, 0) =  4642.
        !      /              ;        /              ;       (i-2)*(i-2)      ;       (i-3)*(i-2)
        coef(0, 2, 0) =   0.  ; coef(1, 2, 0) =   0.  ; coef(2, 2, 0) = 7043.  ; coef(3, 2, 0) = -3882.
        !      /              ;        /              ;        /               ;       (i-3)*(i-3)
        coef(0, 3, 0) =   0.  ; coef(1, 3, 0) =   0.  ; coef(2, 3, 0) =   0.   ; coef(3, 3, 0) = 547.
        ! stencil 1
        !     (i+1)*(i+1)     ;        i*(i+1)        ;       (i-1)*(i+1)      ;       (i-2)*(i+1)
        coef(0, 0, 1) =  547. ; coef(1, 0, 1) =-2522. ; coef(2, 0, 1) = 1922.  ; coef(3, 0, 1) = -494.
        !       /             ;          i*i          ;       (i-1)*i          ;       (i-2)*i
        coef(0, 1, 1) =   0.  ; coef(1, 1, 1) = 3443. ; coef(2, 1, 1) = -5966. ; coef(3, 1, 1) =  1602.
        !       /             ;          /            ;       (i-1)*(i-1)      ;       (i-2)*(i-1)
        coef(0, 2, 1) =   0.  ; coef(1, 2, 1) =   0.  ; coef(2, 2, 1) = 2843.  ; coef(3, 2, 1) = -1642.
        !       /             ;          /            ;        /               ;       (i-2)*(i-2)
        coef(0, 3, 1) =   0.  ; coef(1, 3, 1) =   0.  ; coef(2, 3, 1) =   0.   ; coef(3, 3, 1) = 267.
        ! stencil 2
        !     (i+2)*(i+2)     ;       (i+1)*(i+2)     ;        i*(i+2)         ;       (i-1)*(i+2)
        coef(0, 0, 2) =  267. ; coef(1, 0, 2) =-1642. ; coef(2, 0, 2) = 1602.  ; coef(3, 0, 2) = -494.
        !      /              ;       (i+1)*(i+1)     ;        i*(i+1)         ;       (i-1)*(i+1)
        coef(0, 1, 2) =   0.  ; coef(1, 1, 2) = 2843. ; coef(2, 1, 2) = -5966. ; coef(3, 1, 2) =  1922.
        !      /              ;        /              ;        i*i             ;       (i-1)*i
        coef(0, 2, 2) =   0.  ; coef(1, 2, 2) =   0.  ; coef(2, 2, 2) = 3443.  ; coef(3, 2, 2) = -2522.
        !      /              ;        /              ;        /               ;       (i-1)*(i-1)
        coef(0, 3, 2) =   0.  ; coef(1, 3, 2) =   0.  ; coef(2, 3, 2) =   0.   ; coef(3, 3, 2) = 547.
        ! stencil 3
        !     (i+3)*(i+3)     ;       (i+2)*(i+3)     ;       (i+1)*(i+3)      ;        i*(i+3)
        coef(0, 0, 3) =  547. ; coef(1, 0, 3) =-3882. ; coef(2, 0, 3) = 4642.  ; coef(3, 0, 3) = -1854.
        !      /              ;       (i+2)*(i+2)     ;       (i+1)*(i+2)      ;        i*(i+2)
        coef(0, 1, 3) =   0.  ; coef(1, 1, 3) = 7043. ; coef(2, 1, 3) =-17246. ; coef(3, 1, 3) =  7042.
        !      /              ;        /              ;       (i+1)*(i+1)      ;        i*(i+1)
        coef(0, 2, 3) =   0.  ; coef(1, 2, 3) =   0.  ; coef(2, 2, 3) =11003.  ; coef(3, 2, 3) = -9402.
        !      /              ;        /              ;        /               ;        i*i
        coef(0, 3, 3) =   0.  ; coef(1, 3, 3) =   0.  ; coef(2, 3, 3) =   0.   ; coef(3, 3, 3) = 2107.
      endselect
    endassociate
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endsubroutine set_smoothness_indicators_coefficients
  endsubroutine create

  pure subroutine description(self, string)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Return a string describing the WENO interpolator.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(weno_interpolator_upwind), intent(IN)  :: self   !< WENO interpolator.
  character(len=:), allocatable,   intent(OUT) :: string !< String returned.
  character(len=1)                             :: dummy  !< Dummy string.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  string = 'WENO upwind-biased interpolator'//new_line('a')
  string = string//'  Based on the scheme proposed by ...'//new_line('a')
  write(dummy, '(I1)') 2*self%S - 1
  string = string//'  Provide a formal order of accuracy equals to: '//dummy//new_line('a')
  write(dummy, '(I1)') self%S
  string = string//'  Use '//dummy//' stencils composed by '//dummy//' values'//new_line('a')
  string = string//'  The "interpolate" method has the following public API'//new_line('a')
  string = string//'    interpolate(S, stencil, interpolation)'//new_line('a')
  string = string//'  where:'//new_line('a')
  string = string//'    S: integer, intent(IN), the number of stencils actually used'//new_line('a')
  string = string//'    stencil(1:2, 1-S:-1+S): real, intent(IN), the stencils used'//new_line('a')
  string = string//'    interpolation(1:2, 1-S:-1+S): real, intent(OUT), the interpolated values'
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine description

  pure subroutine interpolate(self, S, stencil, interpolation)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Interpolate the stecil input values computing the actual interpolation.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(weno_interpolator_upwind), intent(IN)  :: self                      !< WENO interpolator.
  integer,                         intent(IN)  :: S                         !< Number of stencils used.
  real,                            intent(IN)  :: stencil(1:, 1 - S:)       !< Stencil used for the interpolation, [1:2, 1-S:-1+S].
  real,                            intent(OUT) :: interpolation(1:)         !< Result of the interpolation, [1:2].
  real                                         :: polynomials(1:2, 0:S - 1) !< Polynomial reconstructions.
  real                                         :: weights(1:2, 0:S - 1)     !< Weights of the stencils.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  call compute_polynomials(polynomials=polynomials)
  call compute_weights(weights=weights)
  call compute_convolution(interpolation=interpolation)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  contains
    pure subroutine compute_polynomials(polynomials)
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Compute the polynomials reconstructions.
    !-------------------------------------------------------------------------------------------------------------------------------
    real, intent(OUT) :: polynomials(1:, 0:) !< Polynomial reconstructions.
    integer           :: s1, s2, f !< Counters.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    polynomials = 0.
    do s1 = 0, S - 1 ! stencils loop
      do s2 = 0, S - 1 ! values loop
        do f = 1, 2 ! 1 => left interface (i-1/2), 2 => right interface (i+1/2)
          polynomials(f, s1) = polynomials(f, s1) + self%poly_coef(f, s2, s1) * stencil(f, -s2 + s1)
        enddo
      enddo
    enddo
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endsubroutine compute_polynomials

    pure subroutine compute_weights(weights)
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Compute the stencils weights.
    !-------------------------------------------------------------------------------------------------------------------------------
    real, intent(OUT) :: weights(1:, 0:)  !< Weights of the stencils, [1:2, 0:S - 1 ].
    real              :: IS(1:2, 0:S - 1) !< Smoothness indicators of the stencils.
    real              :: a(1:2, 0:S - 1)  !< Alpha coefficients for the weights.
    real              :: a_tot(1:2)       !< Sum of the alpha coefficients.
    integer           :: s1, s2, s3, f    !< Counters.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    ! computing smoothness indicators
    do s1 = 0, S - 1 ! stencils loop
      do f = 1, 2 ! 1 => left interface (i-1/2), 2 => right interface (i+1/2)
        IS(f, s1) = 0.
        do s2 = 0, S - 1
          do s3 = 0, S - 1
            IS(f, s1) = IS(f, s1) + self%smooth_coef(s3, s2, s1) * stencil(f, s1 - s3) * stencil(f, s1 - s2)
          enddo
        enddo
      enddo
    enddo
    ! computing alfa coefficients
    a_tot = 0.
    do s1 = 0, S - 1 ! stencil loops
      do f = 1, 2 ! 1 => left interface (i-1/2), 2 => right interface (i+1/2)
        a(f, s1) = self%weights_opt(f, s1) * (1./(self%eps + IS(f, s1))**S) ; a_tot(f) = a_tot(f) + a(f, s1)
      enddo
    enddo
    ! computing the weights
    do s1 = 0, S - 1 ! stencils loop
      do f = 1, 2 ! 1 => left interface (i-1/2), 2 => right interface (i+1/2)
        weights(f, s1) = a(f, s1) / a_tot(f)
      enddo
    enddo
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endsubroutine compute_weights

    pure subroutine compute_convolution(interpolation)
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Compute the polynomials convolution.
    !-------------------------------------------------------------------------------------------------------------------------------
    real, intent(OUT) :: interpolation(1:) !< Left and right (1,2) interface value of reconstructed.
    integer           :: k, f              !< Counters.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    ! computing the convultion
    interpolation = 0.
    do k = 0, S - 1 ! stencils loop
      do f = 1, 2 ! 1 => left interface (i-1/2), 2 => right interface (i+1/2)
        interpolation(f) = interpolation(f) + weights(f, k) * polynomials(f, k)
      enddo
    enddo
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endsubroutine compute_convolution
  endsubroutine interpolate

  ! private methods
  elemental subroutine finalize(self)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Finalize object.
  !---------------------------------------------------------------------------------------------------------------------------------
  type(weno_interpolator_upwind), intent(INOUT) :: self !< WENO interpolator.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  call self%destroy
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine finalize
endmodule type_weno_interpolator_upwind
