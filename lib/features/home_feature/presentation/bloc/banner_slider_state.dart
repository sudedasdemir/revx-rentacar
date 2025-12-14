part of 'banner_slider_cubit.dart';

class BannerSliderState {
  BannerSliderState({required this.currentIndex, required this.banners});

  final int currentIndex;
  final List<BannerModel> banners;
  final CarouselSliderController controller = CarouselSliderController();

  BannerSliderState copyWith({int? currentIndex, List<BannerModel>? banners}) {
    return BannerSliderState(
      currentIndex: currentIndex ?? this.currentIndex,
      banners: banners ?? this.banners,
    );
  }
}
