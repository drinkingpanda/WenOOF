!< Jiang-Shu (upwind) reconstructor object.
module wenoof_reconstructor_js
!< Jiang-Shu (upwind) reconstructor object.

use, intrinsic :: iso_fortran_env, only : stderr=>error_unit
use penf, only : I_P, R_P, str
use wenoof_base_object, only : base_object_constructor
use wenoof_interpolations_factory, only : interpolations_factory
use wenoof_interpolations_object, only : interpolations_object
use wenoof_interpolator_object, only : interpolator_object, interpolator_object_constructor
use wenoof_weights_factory, only : weights_factory
use wenoof_weights_object, only : weights_object

implicit none
private
public :: reconstructor_js
public :: reconstructor_js_constructor

type, extends(interpolator_object_constructor) :: reconstructor_js_constructor
  !< Jiang-Shu (upwind) reconstructor object constructor.
endtype reconstructor_js_constructor

type, extends(interpolator_object) :: reconstructor_js
  !< Jiang-Shu (upwind) reconstructor object.
  !<
  !< @note Provide the *Efficient Implementation of Weighted ENO Schemes*,
  !< Guang-Shan Jiang, Chi-Wang Shu, JCP, 1996, vol. 126, pp. 202--228, doi:10.1006/jcph.1996.0130.
  !<
  !< @note The supported accuracy formal order are: 3rd, 5th, 7th, 9th, 11th, 13th, 15th, 17th  corresponding to use 2, 3, 4, 5, 6,
  !< 7, 8, 9 stencils composed of 2, 3, 4, 5, 6, 7, 8, 9 values, respectively.
  contains
    ! public deferred methods
    procedure, pass(self) :: create                   !< Create reconstructor.
    procedure, pass(self) :: description              !< Return object string-description.
    procedure, pass(self) :: destroy                  !< Destroy reconstructor.
    procedure, pass(self) :: interpolate_int_debug    !< Interpolate values (providing also debug values, interpolate).
    procedure, pass(self) :: interpolate_int_standard !< Interpolate values (without providing debug values, interpolate).
    procedure, pass(self) :: interpolate_rec_debug    !< Interpolate values (providing also debug values, reconstruct).
    procedure, pass(self) :: interpolate_rec_standard !< Interpolate values (without providing debug values, reconstruct).
endtype reconstructor_js

contains
  ! public deferred methods
  subroutine create(self, constructor)
  !< Create reconstructor.
  class(reconstructor_js),        intent(inout) :: self        !< Reconstructor.
  class(base_object_constructor), intent(in)    :: constructor !< Constructor.
  type(interpolations_factory)                  :: i_factory   !< Inteprolations factory.
  type(weights_factory)                         :: w_factory   !< Weights factory.

  call self%destroy
  call self%create_(constructor=constructor)
  select type(constructor)
  class is(interpolator_object_constructor)
    call i_factory%create(constructor=constructor%interpolations_constructor, object=self%interpolations)
    call w_factory%create(constructor=constructor%weights_constructor, object=self%weights)
  endselect
  endsubroutine create

  pure function description(self, prefix) result(string)
  !< Return object string-descripition.
  class(reconstructor_js), intent(in)           :: self             !< Interpolator.
  character(len=*),        intent(in), optional :: prefix           !< Prefixing string.
  character(len=:), allocatable                 :: string           !< String-description.
  character(len=:), allocatable                 :: prefix_          !< Prefixing string, local variable.
  character(len=1), parameter                   :: NL=new_line('a') !< New line character.

  prefix_ = '' ; if (present(prefix)) prefix_ = prefix
  string = prefix_//'Jiang-Shu reconstructor:'//NL
  string = string//prefix_//'  - S   = '//trim(str(self%S))//NL
  string = string//prefix_//self%weights%description(prefix=prefix_//'  ')
  endfunction description

  elemental subroutine destroy(self)
  !< Destroy reconstructor.
  class(reconstructor_js), intent(inout) :: self !< Reconstructor.

  call self%destroy_
  if (allocated(self%interpolations)) deallocate(self%interpolations)
  if (allocated(self%weights)) deallocate(self%weights)
  endsubroutine destroy

  pure subroutine interpolate_int_debug(self, stencil, interpolation, si, weights)
  !< Interpolate values (providing also debug values, interpolate).
  class(reconstructor_js), intent(in)  :: self                 !< Reconstructor.
  real(R_P),               intent(in)  :: stencil(1 - self%S:) !< Stencil of the interpolation [1-S:-1+S].
  real(R_P),               intent(out) :: interpolation        !< Result of the interpolation.
  real(R_P),               intent(out) :: si(0:)               !< Computed values of smoothness indicators [0:S-1].
  real(R_P),               intent(out) :: weights(0:)          !< Weights of the stencils, [0:S-1].
  ! empty procedure
  endsubroutine interpolate_int_debug

  pure subroutine interpolate_int_standard(self, stencil, interpolation)
  !< Interpolate values (without providing debug values, interpolate).
  class(reconstructor_js), intent(in)  :: self                 !< Reconstructor.
  real(R_P),               intent(in)  :: stencil(1 - self%S:) !< Stencil of the interpolation [1-S:-1+S].
  real(R_P),               intent(out) :: interpolation        !< Result of the interpolation.
  ! empty procedure
  endsubroutine interpolate_int_standard

  pure subroutine interpolate_rec_debug(self, stencil, interpolation, si, weights)
  !< Interpolate values (providing also debug values).
  !< @TODO implement smoothness indicator return.
  class(reconstructor_js), intent(in)  :: self                              !< Reconstructor.
  real(R_P),               intent(in)  :: stencil(1:, 1 - self%S:)          !< Stencil of the interpolation [1:2, 1-S:-1+S].
  real(R_P),               intent(out) :: interpolation(1:)                 !< Result of the interpolation, [1:2].
  real(R_P),               intent(out) :: si(1:, 0:)                        !< Computed values of smoothness indicators [1:2, 0:S-1].
  real(R_P),               intent(out) :: weights(1:, 0:)                   !< Weights of the stencils, [1:2, 0:S-1].
  real(R_P)                            :: interpolations(1:2, 0:self%S - 1) !< Stencils interpolations.
  integer(I_P)                         :: f, s                              !< Counters.

  call self%interpolations%compute(stencil=stencil, values=interpolations)
  call self%weights%compute(stencil=stencil, values=weights)
  ! call self%weights%smoothness_indicators_of_rank_2(si=si)
  interpolation = 0._R_P
  do s=0, self%S - 1 ! stencils loop
    do f=1, 2 ! 1 => left interface (i-1/2), 2 => right interface (i+1/2)
      interpolation(f) = interpolation(f) + weights(f, s) * interpolations(f, s)
    enddo
  enddo
  endsubroutine interpolate_rec_debug

  pure subroutine interpolate_rec_standard(self, stencil, interpolation)
  !< Interpolate values (without providing debug values).
  class(reconstructor_js), intent(in)  :: self                              !< Reconstructor.
  real(R_P),               intent(in)  :: stencil(1:, 1 - self%S:)          !< Stencil of the interpolation [1:2, 1-S:-1+S].
  real(R_P),               intent(out) :: interpolation(1:)                 !< Result of the interpolation, [1:2].
  real(R_P)                            :: interpolations(1:2, 0:self%S - 1) !< Stencils interpolations.
  real(R_P)                            :: weights(1:2, 0:self%S - 1)        !< Weights of stencils interpolations.
  integer(I_P)                         :: f, s                              !< Counters.

  call self%interpolations%compute(stencil=stencil, values=interpolations)
  call self%weights%compute(stencil=stencil, values=weights)
  interpolation = 0._R_P
  do s=0, self%S - 1 ! stencils loop
    do f=1, 2 ! 1 => left interface (i-1/2), 2 => right interface (i+1/2)
      interpolation(f) = interpolation(f) + weights(f, s) * interpolations(f, s)
    enddo
  enddo
  endsubroutine interpolate_rec_standard
endmodule wenoof_reconstructor_js