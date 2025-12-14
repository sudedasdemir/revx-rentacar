import 'package:flutter_bloc/flutter_bloc.dart';

class BottomNavigationState {
  final int selectedIndex;
  BottomNavigationState({required this.selectedIndex});
}

class BottomNavigationCubit extends Cubit<BottomNavigationState> {
  BottomNavigationCubit() : super(BottomNavigationState(selectedIndex: 0));

  void onItemTap({required int index}) {
    emit(BottomNavigationState(selectedIndex: index));
  }
}
