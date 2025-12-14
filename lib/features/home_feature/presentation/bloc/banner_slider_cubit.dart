import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_app/features/home_feature/data/models/banner_model.dart';
import 'package:firebase_app/features/home_feature/data/repositories/banner_repository.dart';

part 'banner_slider_state.dart';

class BannerSliderCubit extends Cubit<BannerSliderState> {
  final BannerRepository _repository;
  StreamSubscription<List<BannerModel>>? _bannerSubscription;

  BannerSliderCubit({required BannerRepository repository})
    : _repository = repository,
      super(BannerSliderState(currentIndex: 0, banners: [])) {
    _loadBanners();
  }

  void _loadBanners() {
    _bannerSubscription?.cancel();
    _bannerSubscription = _repository.getBanners().listen(
      (banners) {
        emit(state.copyWith(banners: banners));
      },
      onError: (error) {
        print('Error loading banners: $error');
        emit(state.copyWith(banners: []));
      },
    );
  }

  void onPageChanged({required final int index}) {
    emit(state.copyWith(currentIndex: index));
  }

  @override
  Future<void> close() {
    _bannerSubscription?.cancel();
    return super.close();
  }
}
