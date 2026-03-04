import "./resolveAssetSourcePolyfill";

import { NavigationContainer } from "@react-navigation/native";
import { createStackNavigator } from "@react-navigation/stack";
import { GestureHandlerRootView } from "react-native-gesture-handler";

import type { Routes } from "./Route";
import { Wireframe } from "./Wireframe";

const Stack = createStackNavigator<Routes>();

function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <NavigationContainer>
        <Stack.Navigator
          initialRouteName="Wireframe"
          screenOptions={{ cardStyle: { flex: 1 } }}
        >
          <Stack.Screen name="Wireframe" component={Wireframe} />
        </Stack.Navigator>
      </NavigationContainer>
    </GestureHandlerRootView>
  );
}

// eslint-disable-next-line import/no-default-export
export default App;
